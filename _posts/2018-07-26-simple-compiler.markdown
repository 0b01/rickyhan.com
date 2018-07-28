---
layout: post
title:  "Writing a Simple Compiler from Scratch"
date:   2018-07-26 00:00:00 -0400
categories: jekyll update
---

This blog post is a short demo of writing a quick and simple compiler for BPF bytecode.

# BPF?

Deep inside the Linux networking stack, there is a universal in-kernel virtual machine for filtering packets. The VM is called Berkeley Packet Filter. It is programmed with BPF bytecode which is a dead simple instruction set and very nice to generate against.

So what is BPF for? Like the name suggest, filtering network packets. Basically, programs load data from packet, perform arithmetic operations, compare constants or bits at offset locations, and finally output a single boolean value to either reject or accept the packet. The user can basically create the filter, attach it to the kernel, and get filtered packets from that syscall. To ensure all BPF program terminates, all jmps must be forward(no loops) and there can be at most 4096 instructions. Overall, it's a pretty fascinating construction.

To see the BPF bytecode in action, you can use tcpdump(libpcap) to compile a filter into BPF.

    ~$ sudo tcpdump -d ip and udp
    (000) ldh      [12]
    (001) jeq      #0x800           jt 2	jf 5
    (002) ldb      [23]
    (003) jeq      #0x11            jt 4	jf 5
    (004) ret      #262144
    (005) ret      #0

It's pretty straightforward, it loads some half byte from linktype offset and checks if it's a constant and jumps based on the result. Notice how (jt)jump true and jump false are part of the instruction set because pretty much all BPF programs are a series of if then else statements.

```c
struct sock_filter {  /* Filter block */
    __u16   code;     /* Actual opcode */
    __u8    jt;       /* Jump true */
    __u8    jf;       /* Jump false */
    __u32   k;        /* Generic multiuse field */
};
```


# Embedded DSL in Python

As much as I love writing parsers, sometimes the language is just not interesting enough to justify handcrafting one. To avoid the complexity of maintaining a frontend, I chose to embed the DSL in Python. Python is great for a lot of things but writing a compiler is not one of them. I only used Python because the project is very simple...

Basically, by overloading operators in Python, operations on the object is equivalent to the parse tree.

```python
class Node(object):
    def __init__(self, name=None):
        self.name = name
    def __bool__(self):
        raise TypeError("Don't mistake node with bool.")
    def __invert__(self):
        return UnaryNode('not', self)
    def __and__(self, other):
        return BinaryNode('and', self, other)
    def __rand__(self, other):
        return BinaryNode('and', other, self)
    def __or__(self, other):
        return BinaryNode('or', self, other)
    def __ror__(self, other):
        return BinaryNode('or', other, self)
class BinaryNode(Node):
    def __init__(self, op, left, right):
        self.op = op
        self.left = left
        self.right = right
    def __repr__(self):
        return "(%s %s %s)" % (self.left, self.op, self.right)
class UnaryNode(Node):
    def __init__(self, op, operand):
        self.op = op
        self.operand = operand
    def __repr__(self):
        return "%s %s" % (self.op, self.operand)

class ProtocolNode(Node):
    def __init__(self, proto):
        self.proto = proto
    def __repr__(self):
        return self.proto
class UdpNode(ProtocolNode):
    def __init__(self):
        super(UdpNode, self).__init__("udp")
class TcpNode(ProtocolNode):
    def __init__(self):
        super(TcpNode, self).__init__("tcp")
class IcmpNode(ProtocolNode):
    def __init__(self):
        super(IcmpNode, self).__init__("icmp")

class WhenNode(Node):
    def __init__(self, cond, then_node, else_node):
        self.cond = cond
        self.then_node = then_node
        self.else_node = else_node
    def __repr__(self):
        return "(if (%s) (%s) else (%s))" % (self.cond, self.then_node, self.else_node)
def when(cond, then_node, else_node):
    return WhenNode(cond, then_node, else_node)

udp = UdpNode()
tcp = TcpNode()
icmp = IcmpNode()
ip = IpNode()
```

Some example programs:

```python
program = ip & udp & host("localhost")
program = (udp | tcp) & src("box0") & dst("box1")
program = ip & rand(0.1) & icmp # sample 1/10 icmp packets
```

# Assembly bytecode generation

Now I have a query simplifier that takes this tree and runs through z3 but that topic is for another time. The compiler also employs some crazy optimization antics which are beyond the scope of this post. And for the sake of simplicity, I removed the offsets of where each field is in the packet so this is pretty just pseudo assembly. Code genenerator is a class that walks the AST.

```python
class Codegen(object):
    def __init__(self):
        self.cp = 0
        self.program = []

    def compile(self, node):
        ret_t = Instr(Offset(-1), "ret", 0, 0, "ok")
        ret_f = Instr(Offset(-1), "ret", 0, 0, "err")
        self.compile_aux(node, ret_t.offset, ret_f.offset)
        self.update(ret_t.offset)
        self.add(ret_t)
        self.update(ret_f.offset)
        self.add(ret_f)

    def compile_aux(self, node, t, f):
        class_name = type(node).__name__
        op_name = node.__dict__.get("op")
        fn_name = class_name + "_" + op_name
        getattr(self, fn_name)(node, t, f)

    def IcmpNode_(self, node, t, f):
        ret = Instr(Offset(self.cp), "jeq", t, f, node.proto)
        self.add(ret)

    def TcpNode_(self, node, t, f):
        ret = Instr(Offset(self.cp), "jeq", t, f, node.proto)
        self.add(ret)

    def FalseNode_(self, node, t, f):
        self.add(Instr(Offset(self.cp), "jmp", f, f, 0))

    def TrueNode_(self, node, t, f):
        pass

    def WhenNode_(self, node, t, f):
        label_else = self.new_label()
        label_next = self.new_label()
        self.compile_aux(node.cond, 0, label_else)
        self.compile_aux(node.then_node, 0, f)
        self.add(Instr(Offset(self.cp), "jmp", label_next, 0, 0))
        self.update(label_else)
        self.compile_aux(node.else_node, 0, f)
        self.update(label_next)

    def UnaryNode_not(self, node, t, f):
        self.compile_aux(node.operand, f, t)

    def UdpNode_(self, node, t, f):
        ret = Instr(Offset(self.cp), "jeq", t, f, node.proto)
        self.add(ret)

    def IpNode_(self, node, t, f):
        ret = Instr(Offset(self.cp), "jeq", t, f, node.name)
        self.add(ret)

    def BinaryNode_and(self, node, t, f):
        if f.off == 0:
            label = self.new_label()
        else:
            label = f
        self.compile_aux(node.left, 0, label)
        self.compile_aux(node.right, t, f)
        if f.off == 0:
            self.update(label)

    def BinaryNode_or(self, node, t, f):
        if t.off == 0:
            label = self.new_label()
        else:
            label = t
        self.compile_aux(node.left, label, 0)
        self.compile_aux(node.right, t, f)
        if t.off == 0:
            self.update(label)

    def new_label(self):
        return Offset(self.cp)

    def update(self, offset):
        if type(offset) == Offset:
            offset.off = self.cp
        elif type(offset) == Instr:
            offset.offset.off = self.cp

    def add(self, stmt):
        self.program.append(stmt)
        self.cp += 1


class Offset(object):
    def __init__(self, off):
        self.off = off

    def __sub__(self, other):
        if type(other) == Offset:
            return Offset(self.off - other.off)
        elif type(other) == int:
            return Offset(self.off - other)
        else:
            raise NotImplementedError

    def __rsub__(self, other):
        return self.off - int(other)

    def __repr__(self):
        return "[%d]" % self.off


class Instr(object):
    def __init__(self, off, op, a, b, c):
        self.offset = off
        self.op = op
        self.a = a
        self.b = b
        self.c = c

    def __repr__(self):
        return "(%s) { %s %s %s %s }" % (
            self.offset,
            self.op,
            self.a,
            self.b,
            self.c
        )

    def compile(self):
        return "(%s) { %s %s %s %s }" % (
            self.offset,
            self.op,
            self.adjust(self.a),
            self.adjust(self.b),
            self.c
        )

    def adjust(self, val):
        if type(val) == Offset:
            return val - self.offset - 1
        elif type(val) == int:
            return val
        else:
            raise NotImplementedError
```

To convert the query tree to bytecode, simply call `Codegen.compile` which creates return bool values (-1, 0) to later "backpatch" the jump locations.

> Backpatching means modifying jump location offsets that wasn't known before until the rest of the code is generated. I put backpatching in quotation marks because it's not really using the canonical backpatching algorithm but simply updating the Offset reference during tree traversal. Python is pass by object so I have to wrap the offset in its own class to pass it by reference.

`compile_aux` recursively dispatches different compilation methods. Passing in the true false jump offsets is a common practice for compiling boolean statements. If you are still confused at this point, there's always the dragon book.

```
input:  (ip and (udp or tcp))
(0) { jeq 0 [4] ip }
(1) { jeq [3] 0 udp }
(2) { jeq [3] [4] tcp }
(3) { ret 0 0 ok }
(4) { ret 0 0 err }
```

# Conclusion

In this post I demonstrated how to write a simple bytecode compiler in vanilla Python.

# Crib Dragging

First of all, the plain text is the following:

```
HELLO AGAIN SCIENTIST I DID NOT PLAN TO MAKE THIS EASY BUT I MOSTLY USED SMALL WORDS QUANTUM LEMUR
VICTORY IN SEOUL HOW MANY MATHEMATICIANS DOES IT TAKE TO SCREW IN A LIGHTBULB PHANTOMESS LADY BIRD
ABSTRACTS NONSENSE ATTACK AT DAWN SERIOUSLY ATTACK AT DAWN OR DONT WHATEVER I GUESS VENONA PROJECT
```

It took me a total of 5 hours from start to finish which is really not long considering the nature of crib-dragging is not far from that of Scrabble or Crossword which takesa bit longer per game.

# The task

I have 3 encrypted text messages encode in bits which translates to three xor (A ^ B, A ^ C, and B ^ C).

# Encoding scheme
1 char is 1 byte (8 bits) but ASCII encoding only uses 7 bits. So each character is encoded into 7 bits.

# Breaking the code

So I started off with matlab:

```MATLAB
m1 = csvread('message1.txt');
m2 = csvread('message2.txt');
m3 = csvread('message3.txt');

m1_x_m2 = xor(m1, m2);
m1_x_m3 = xor(m1, m3);
m2_x_m3 = xor(m2, m3);

S = strcat(char(65:90),' ');


mapObj = containers.Map('keyType','double','valueType','any');

for i=1:length(S)
    for j=1:length(S)
            letter_1 = string2bits(S(i));
            letter_2 = string2bits(S(j));
            l1_x_l2 = xor(letter_1, letter_2);
            pair = strcat(S(i),S(j)); % 'AB'
            pair = strcat(strcat('[', strcat(pair, ']')), ',');
            ord = l1_x_l2'*(2.^(size(l1_x_l2',2)-1 :-1:0))';
            if isKey(mapObj, ord)
                current = mapObj(ord);
                mapObj(ord) = strcat(current,pair);
            else
                mapObj(ord) = pair;
            end
    end
end

for i=1:length(m1_x_m2)
    bits = m1_x_m2(:,i)
    ord = bits'*(2.^(size(bits',2)-1 :-1:0))'
    mapObj(ord)
end

```

The concept of crib dragging is straightforward but not easy by any means. The three xor'd text effectively removed the encryption and all I need to do is figure out one message and the other two will incrementally follow. It is also nice to have 2 other potential text for sanity check. So I started breaking code one by one, originally I used MATLAB to build up a hashmap and wanted to run it against a dictionary. But this algorithm is so difficult that I have not idea how to implement in MATLAB. Already spent an hour on this, I decided to look elsewhere and go back to the basics. Granted, we are supposed to use MATLAB to break this. The incremental nature of this sort of computation reminds me of spreadsheet: changing 1 cell creates ripple effect for the other two. This tempted me to use a spreadsheet. However, I don't have Excel installed on my computer and I thought handcoding the reactions of changing one cell is not difficult. Assigning 1 character c in message 1 means assign `xor(c, m1_xor_m2)` to message 2, `xor(c, m1_xor_m3)` to message 3.

I thought about trying out `incremental` library in OcaML but decided to use Python which I know very well to code a custom reactive "spreadsheet".

After reading in the file, I automated the procedure of xor the spaces according to the reading material.

```
# first we automate xor with ' '
for i in range(length):
    bits1 = m1_x_m2[i]
    bits2 = m1_x_m3[i]
    bits3 = m2_x_m3[i]
    ONE_TWO_SPACE = str(bits1).startswith('1')
    ONE_THREE_SPACE = str(bits2).startswith('1')
    TWO_THREE_SPACE = str(bits3).startswith('1')

    if ONE_TWO_SPACE and ONE_THREE_SPACE:
        msg1[i] = ' '
        msg2[i] = xor_space(bits1)
        msg3[i] = xor_space(bits2)
    elif ONE_TWO_SPACE and TWO_THREE_SPACE:
        msg1[i] = xor_space(bits1)
        msg2[i] = ' '
        msg3[i] = xor_space(bits3)
    elif ONE_THREE_SPACE and TWO_THREE_SPACE:
        msg1[i] = xor_space(bits2)
        msg2[i] = xor_space(bits3)
        msg3[i] = ' '
    # print m1_x_m2[i], m1_x_m3[i], m2_x_m3[i], msg1[i], msg2[i], msg3[i]
```

This outputs the following:

```
0         1         2         3         4         5         6         7         8         9
01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567
--------------------------------------------------------------------------------------------------
..... .G.IN ....N.I.T . . . N.. .L.. .. M..E T..S E..  .U.C. MO..LYW.... ..A.  ....S ...N.U. L....
.....R. .N S.... .O. M.N.I.AT..M.T..I..S ..ES .. TA..YT. . .EW .. AW....T..L.LP....OM... .A.Y ....
.....A.T. NO....S. .TT.C.I.T ..W. ..R..US.. AT..CK ..YD.W.C.R D..T  ....V.. .LG.... V...N. .RO....
```

At this point, a lot of the words can be decrypted. Better yet, when one message is decrypted, the other two follow. So I coded a REPL to experiment interactively using commands such as `set 1 16 A` or `word 1 0 HELLO`. This was a huge quality of life improvement.

```
..... AGAIN ....N.I.T . . . N.. .L.. .. M..E THIS E..  .U.C. MO..LYW.... ..A.  ....S ...N.U. L....
.....RY IN S.... .O. M.N.I.AT..M.T..I..S ..ES IT TA..YT. . .EW .. AW....T..L.LP....OM... .A.Y ....
.....ACTS NO....S. .TT.C.I.T ..W. ..R..US.. ATTACK ..YD.W.C.R D..T  ....V.. .LG.... V...N. .RO....
```

I filled the obvious words and found out that it really did work!

```
HELLO AGAIN SCIENTIST I D . N.. .L.. .. M..E THIS E..  .U.C. MO..LYW.... ..A.  ....S ...N.U. L....
VICTORY IN SEOUL HOW MANYI.AT..M.T..I..S ..ES IT TA..YT. . .EW .. AW....T..L.LP....OM... .A.Y ....
ABSTRACTS NONSENSE ATTACKI.T ..W. ..R..US.. ATTACK ..YD.W.C.R D..T  ....V.. .LG.... V...N. .RO....
```

Filled out some more obvious ones based on context. Now I'm stuck, after looking at it for a while and using crossword word finder to no avail. Then I realized the caveat in using XOR. When m1 == ' ', m2 == m3, xor(m1, m2) == xor(m1, m3) have the same bits when m1 == 'A', m2 == m3 == ' '. So instead of having 2 messages same, the third one should have that value based on simple probability.

This got a lot easier, and after 10 minutes or so, the message was broken except the last part.

```
HELLO AGAIN SCIENTIST I DID NOT PLAN TO MAKE THIS EASY BUT I MOSTLY USED SMALL ....S QUANTUM LEMUR
VICTORY IN SEOUL HOW MANY MATHEMATICIANS DOES IT TAKE TO SCREW IN A LIGHTBULB P....OMESS LADY BIRD
ABSTRACTS NONSENSE ATTACK AT DAWN SERIOUSLY ATTACK AT DAWN OR DONT WHATEVER I G.... VENONA PROJECT
```

This I really had no idea based on context alone. I decided to use a bruteforce search and coded one... By sheer chance, I got inspired by Lady Bird and typed in Phantom (Thread, which is kino) and turned out to be correct.

Although highly unlikely, there's still a tiny chance that the key may be different from the one I have found. The sample space of English language is smaller than the search space. To test this and also to add some MATLAB rigor, I checked the key with MATLAB:

```matlab
m1 = csvread('message1.txt');
m2 = csvread('message2.txt');
m3 = csvread('message3.txt');

plain_text1 = string2bits('HELLO AGAIN SCIENTIST I DID NOT PLAN TO MAKE THIS EASY BUT I MOSTLY USED SMALL WORDS QUANTUM LEMUR');
plain_text2 = string2bits('VICTORY IN SEOUL HOW MANY MATHEMATICIANS DOES IT TAKE TO SCREW IN A LIGHTBULB PHANTOMESS LADY BIRD');
plain_text3 = string2bits('ABSTRACTS NONSENSE ATTACK AT DAWN SERIOUSLY ATTACK AT DAWN OR DONT WHATEVER I GUESS VENONA PROJECT');

key1 = xor(plain_text1, m1);
key2 = xor(plain_text2, m2);
key3 = xor(plain_text3, m3);

key1 - key2 % zero which means it is the same for message1 and message2
key2 - key3 % zero which means it is the same for message2 and message3

```

Overall, it was a pretty interesting assignment but I'd rather not do it again :p

Finally, here is the code (Python) I wrote for this assignment:

```py
import string

to_bits = lambda x: "{:07b}".format(x)
xor_letter = lambda x, letter: chr(int(x,2) ^ ord(letter))
xor_space = lambda x: xor_letter(x, ' ')

def read_f(fname):
    f1 = file(fname).read().split('\n')[:-1]
    f1 = map(lambda x: x.split(','), f1)
    bitssss = []
    for i in range(len(f1[0])):
        bits = []
        for j in range(7):
            bits.append(f1[j][i])
        bitssss.append(''.join(bits))
    return bitssss

m1 = map(lambda x:int(x,2), read_f('message1.txt'))
m2 = map(lambda x:int(x,2), read_f('message2.txt'))
m3 = map(lambda x:int(x,2), read_f('message3.txt'))

m1_x_m2 = map(lambda (a,b): to_bits(a^b), zip(m1,m2))
m1_x_m3 = map(lambda (a,b): to_bits(a^b), zip(m1,m3))
m2_x_m3 = map(lambda (a,b): to_bits(a^b), zip(m2,m3))

length = len(m1_x_m2)

msg1 = ['.'] * length
msg2 = ['.'] * length
msg3 = ['.'] * length

# first we automate xor with ' '
for i in range(length):
    bits1 = m1_x_m2[i]
    bits2 = m1_x_m3[i]
    bits3 = m2_x_m3[i]
    ONE_TWO_SPACE = str(bits1).startswith('1')
    ONE_THREE_SPACE = str(bits2).startswith('1')
    TWO_THREE_SPACE = str(bits3).startswith('1')

    if ONE_TWO_SPACE and ONE_THREE_SPACE:
        msg1[i] = ' '
        msg2[i] = xor_space(bits1)
        msg3[i] = xor_space(bits2)
    elif ONE_TWO_SPACE and TWO_THREE_SPACE:
        msg1[i] = xor_space(bits1)
        msg2[i] = ' '
        msg3[i] = xor_space(bits3)
    elif ONE_THREE_SPACE and TWO_THREE_SPACE:
        msg1[i] = xor_space(bits2)
        msg2[i] = xor_space(bits3)
        msg3[i] = ' '
    print m1_x_m2[i], m1_x_m3[i], m2_x_m3[i], msg1[i], msg2[i], msg3[i]

indices = map(lambda x:''.join(x), zip(*map(lambda x: "{:02}".format(x), range(length))))
def print_all():
    print '\n'.join(indices)
    print '-'*length
    print ''.join(msg1)
    print ''.join(msg2)
    print ''.join(msg3)

print_all()

def parse_set(tokens):
    msgidx = int(tokens[1]) - 1
    idx = int(tokens[2])
    letter = tokens[3]
    if letter == 'space':
        letter = ' '
    if msgidx == 0:
        msg1[idx] = letter
        msg2[idx] = xor_letter(m1_x_m2[idx], letter)
        msg3[idx] = xor_letter(m1_x_m3[idx], letter)
    elif msgidx == 1:
        msg1[idx] = xor_letter(m1_x_m2[idx], letter)
        msg2[idx] = letter
        msg3[idx] = xor_letter(m2_x_m3[idx], letter)
    elif msgidx == 2:
        msg1[idx] = xor_letter(m1_x_m3[idx], letter)
        msg2[idx] = xor_letter(m2_x_m3[idx], letter)
        msg3[idx] = letter

def word(msg, start, word):
    ret = []
    for (i,letter) in enumerate(word):
        ret.append("set {} {} {}".format(
            msg, start + i, letter
        ))
    return ret


known = [
    # again
    "set 1 06 A",
    "set 1 08 A",
    # attack
    "set 3 46 T",
    "set 3 47 A",

    # hello

]

known += word(1, 00, "HELLO")
known += word(3, 10, "NONSENSE")
known += word(1, 12, "SCIENTIST")
known += word(3, 19, "ATTACK")
known += word(1, 85, "QUANTUM")
known += word(1, 93, "LEMUR")
known += word(3, 34, "CURIOUSLY")
known += word(2, 49, "TAKE")
known += word(2, 54, "TO")
known += word(2, 26, "MATHEMATICIANS")
known += word(1, 25, "I")
known += word(1, 53, "Y")
known += word(2, 57, "SCREW")
known += word(1, 61, "MOSTLY")
known += word(3, 67, "WHATEVER")
known += word(2, 68, "LIGHTBULB")
known += word(1, 73, "SMALL")
known += word(2, 78, "PHANTOM")

for i in known:
    parse_set(i.split())

mapping = {}
for i in string.ascii_uppercase:
    for j in string.ascii_uppercase:
        if i != j:
            bits = to_bits(ord(i) ^ ord(j))
            s = i+j
            s = ''.join(sorted(s))
            if bits in mapping:
                mapping[bits].add(s)
            else:
                mapping[bits] = set()
                mapping[bits].add(s)
mapping['0000000'] = []


cmd = ''
while cmd != 'quit':
    cmd = raw_input("Enter command: ")
    if cmd == '':
        print_all()
        continue
    tokens = cmd.split()
    if tokens[0] == 'set': # set 1 50 'A'
        parse_set(tokens)
        print_all()
    elif tokens[0] == '?': # ? 26
        idx = int(tokens[1])
        print m1_x_m2[idx], mapping[m1_x_m2[idx]]
        print m1_x_m3[idx], mapping[m1_x_m3[idx]]
        print m2_x_m3[idx], mapping[m2_x_m3[idx]] 
    elif tokens[0] == 'word': # word 1 10 HELLO
        msgidx = int(tokens[1]) 
        startidx = int(tokens[2])
        word = tokens[3]
        for i in word(msgidx, startidx, word):
            print i
            parse_set(i.split())
        print_all()
    elif tokens[0] == 'try': # try 1 26
        msgidx = int(tokens[1])
        idx = int(tokens[2])
        possible = ""
        if msgidx == 1:
            possible = "".join(mapping[m1_x_m2[idx]])
        elif msgidx == 2:
            possible = "".join(mapping[m2_x_m3[idx]])
        elif msgidx == 3:
            possible = "".join(mapping[m1_x_m3[idx]])
        for ch in possible:
            print ch
            parse_set(['set', msgidx, idx, ch])
            print_all()
```
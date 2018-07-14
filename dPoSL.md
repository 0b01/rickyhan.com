# Delegated Proof of Stakeholder Latency (dPoSL)

The greatest challenge of blockchains today is scalability. In any fault tolerant consensus protocol, there is a fundamental tradeoff between throughput(tx/sec), scale(number of participating nodes) and latency(time to finality). The position of a blockchain on this tradeoff triangle depends on the usecase, and mainly developer's predisposition. This post deals with incentivizing low latency at the expense of decentralization and bandwidth throughput. My day job at a prop shop deals extensively with time synchronization and latency measurement in a distributed network topology so the topic has been on my mind recently.

## Bottleneck in DLT systems

Measurements have shown that network overhead is the bottleneck(not cryptography or disk I/O). The nature of a decentralized network means long propagation times. The number of messages required to reach consensus grows exponentially with node count. Most efforts in speeding up blockchains are focused on the consensus layer. My personal preferences are delegated bookkeepper such as DPoS and dBFT. These new protocols are only faster because they limit the number of participating nodes in the consensus process. They circumvent the fundamental source of latency from the network layer. To fix blockchain scalability, people should start looking for new incentivization designs at the network layer.

The function of the network layer is to propagate transaction messages. Some blockchains(IOTA, Raiblocks) take advantage of P2P overlay network topology such as an expander graph which has favorable properties if the network constists only of honest nodes(in the prescence of byzantine adversaries) and don't work very well for highly volatile graphs. The other approach, incentivization for dissemination of messages, especially with low latency, is an open problem.

## Delegated Proof of Stakeholder Latency

The ultimate goal is to design a robust fee-splitting structure for a group of delegated stakeholders in a PoS-based blockchain. The fee structure should reward low latency in message passing and processing so as to achieve faster consensus and finality during each designated epoch. The consensus algorithm is called dPoSL(Delegated Proof of Stakeholder Latency) and should be viewed as a hybrid of PoW and PoS where the incentive is shifted towards hardware providing faster connections, instead of mining rigs churning out useless hashes. Under this fee structure, stakeholders are incentivized to achieve low network latency not unlike high frequeny traders.

The core mechanism of dPoSL is similar to that of dPoS and dBFT in that it uses an election mechanism such as proxy voting, delegated stake or Proof of Burn to assemble a dynamic group of bookkeepers. Note the voting process is continuous. After the bookkeepers/block producers are selected, they use a consortium consensus algorithm such as BFT to pass latency information, finalize blocks, update state machine and propagate transactions within each interval period. The fees from each block is split according to node latency and roles which is discussed below.

## Trustless Latency Measurement

Quoting satoshi from Bitcoin white paper:

> The solution we propose begins with a timestamp server. A timestamp server works by taking a hash of a block of items to be timestamped and widely publishing the hash, such as in a newspaper or Usenet post. The timestamp proves that the data must have existed at the time, obviously, in order to get into the hash. Each timestamp includes the previous timestamp in its hash, forming a chain, with each additional timestamp reinforcing the ones before it.

Accurate time measurement is difficult for a distributed system. On top of that, in the context of blockchain, it has to be done in trustlessly. Fortunately, BFT guarantees that as long as 2/3 nodes are honest, an agreement can be reached. Nodes agree on their latency statistics which is then used accordingly to spilt fees among themselves.

The fees are split by edge latency. Since there may be pairwise latency asymmetry, the latency of the edge will be the average of A->B and A<-B.

Consider the network N: {A,B,C}

```
A - B
 \ /
  C
```

is an expander network with largest degree of connecivity.

Invariants:
1. C receives a packet containing latency information from A to B from B signed with B's private key.
2. C receives a packet containing latency information from B to A from A signed with A's private key.
3. A receives a packet containing latency information from C to B from B signed with B's private key.
4. A receives a packet containing latency information from B to C from C signed with C's private key.
5. B receives a packet containing latency information from A to C from C signed with C's private key.
6. B receives a packet containing latency information from C to A from A signed with A's private key.

Let n be the number of nodes in the consortium, there are n(n+1) messages.

From the perspective of one node:
1. A initiates a packet containing a random seed and a list of nodes(in this case [B,C]).
2. A sends the packet to B.
3. B receives the packet, signs it with its private key
4. B sends the packet back to A concluding round trip time(RTT) measurement. (UDP)
5. B additionaly will send the same signed packet to C.
6. C receives the packet from B and signs with private key
7. C sends the packet back to B concluding RTT.
8. C also sends the packet to A where A will get the total multi-node time for correcting disprepency.

# Asymmetric Cryptography Guarantee with irreversible hashing

```
|
v
A -> B
A sends raw seed without any encryption.
-----------------------
     |
     v
A -> B -> A
B sends hash so A can verify that B has indeed received seed
A -> B -> C
B hashes raw seed with its public key and sends to C

hash(seed + Bpub)
-----------------------
          |
          v
A -> B -> C -> A
C hashes the received message with C' public key and
C doesn't know the seed so unable to reproduce the hash
-----------------------
               |
               v
A -> B -> C -> A

hash(hash(seed, Bpub), Cpub)
```


Each node will have its own measurements and will try to reach consensus based on its own calculations of pairwise latency.

A,B,C in each has its own latency measurement between itself and every other node along with a copy of latency information between each node with cryptographic guarantees. So during the consensus stage, the nodes will agree on the upper bound between each and every edge which may be an adjustable threshold hardcoded in the blockchain software. Then it follows by the property of BFT, if 66% of nodes are honest and in agreement then the latency measurement will achieve 100% finality. The latency information consensus is achieved and encoded at the same time with block transaction agreement so the overhead should be fairly minimal. Fee is split according to pairwise latency and nodes are paid accordingly.

The payload of the message is simply the latency between each node.

More details will follow as I continue to flesh this out and possibly a proof of concept too.

## Sources:

http://docs.neo.org/en-us/#consensus-mechanism-dbft

https://eprint.iacr.org/2016/199.pdf

https://hackernoon.com/a-hitchhikers-guide-to-consensus-algorithms-d81aae3eb0e3

https://fc16.ifca.ai/bitcoin/papers/CDE+16.pdf

https://steemit.com/cardamon/@dan/peer-review-of-cardano-s-ouroboros

https://www.usenix.org/conference/nsdi18/presentation/geng

https://infoscience.epfl.ch/record/228942/files/main.pdf

https://eng.paxos.com/why-arent-distributed-systems-engineers-working-on-blockchain-technology


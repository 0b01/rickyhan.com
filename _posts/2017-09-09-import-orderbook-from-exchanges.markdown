---
layout: post
title:  "Gradient Trader Part 0: Building a Cryptocurrency Trading Bot"
date:   2017-09-09 11:05:01 -0400
categories: jekyll update
---

I am really excited about my new project. It is a fairly sophisticated crypto trading bot built with TensorFlow. In the upcoming series of posts, I will share some details on how it was built. Unfortunately, since the bot is profitable, it will be operating in stealth mode and won't be open-sourced. However, the non-mission-critical parts will be. For example, I am currently porting visualization charts and interactive graphs into a module of its own. Expect pretty graphics soon.

The intention is to use this blog as a real-time lab report and tutorial for new quant enthusiasts. Financial demos are few and far between so I hope this will provide some value to you. This is the first post in the installment. In this post I'll show how to import limit order book updates into your own database for later use. A wise man once said, 99% of programming is moving a chunk of data from one place to another, transforming in the process. Order book update is no exception. Here, we listen to every limit order update emitted from the exchange's websocket and store it in a PostgreSQL database. Reconstructing an LOB is not covered.

# The State of Cryptocurrency Trading

Cryptocurrency is the Wild West of trading. Pump and dump scams happen on an hourly basis. Even the higher capitalization markets experience huge price swings that can easily wipe out traditional investors. Market manipulation is the norm and behavior is irrational and counterintuitive. Some strategies can lock people away if executed in a regulated environment.

Cryptocurrency is traded on digital exchanges to which access is universal as long as the trader has an Internet connection. High volatility and low barrier of entrance provide an enormous appeal to casual day traders who trade based on market sentiment almost entirely. As a result, there is a lot of "hype money" flowing around major cryptocurrency exchanges, which means cryptocurrency is fertile ground for pattern matching algorithm to flourish.

## Market Microstructure

### Exchanges

#### Presence of HFT

The speed of cryptocurrency exchanges are 1000 times slower than that of stocks and futures. Of course, some exchanges are faster than others. The fastest, most advanced exchange as of September 2017 is Coinbase GDAX. However, it may not be the most friendly exchange to run your strategy. Most exchanges have millisecond time-scale resolution which means a lot of new HFT strategies are rendered useless. Modern HFT trading strategy requires microsecond resolution. However, there are plenty of market makers operating on a larger time-scale. The Ether Flash Crash only took 45 milliseconds, way faster than a human being can process. And, liquidity taking strategies(filling a mispriced order) will always be a speed game. Afterall, the bitcoin markets are so small that most HFT algorithms are limited.

Other than GDAX, most exchanges are neither fast enough nor liquid enough. For some exchanges, the slow speed may be an intentional design choice as HFT is discouraged in order to protect investors and to stablize an already volatile market. There may also be paid firehose and backdoor market access unknown to ordinary traders. This is a possibility because of lack of regulation.

#### Fee Schedule

Differences in fee schedules encourage different market microstructure and trading behaviors.

|           | Coinbase GDAX | Bitfinex    | Poloniex      | Bittrex |
|-----------|---------------|-------------|---------------|---------|
| Maker Fee | 0%            | 0% - 0.1%   | 0% - 0.15%    | 0.25%   |
| Taker Fee | 0.1% - 0.25%  | 0.1% - 0.2% | 0.05% - 0.25% | 0.25%   |

The maker-taker model offers strong benefits such as greater liquidity and a smaller bid-ask spread. However, some exchanges are offering a flat fee for both makers and takers so there is less incentives for high frequency traders. One prominent example is Bittrex. For people who read Flash Boys, Bittrex is similar to IEX as GDAX is to NYSE.

#### Developer API

The other prominent feature is the minimal API. It doesn't send the exact time an order book update happened. Instead, several BUY, SELL, and FILL updates are batched together in a WebSocket frame over the duration of a `Nounce`.

However, the techniques required to scale a live order book in real-time will be the same regardless of the intended use case. So while the strategies will be different from what we know as HFT, the systems in use will be very similar.

## Why I Chose Bittrex

The choice of Bittrex is straightforward since the prediction engine simulates how a human trader would place orders(albeit faster in execution). It is an **investor-friendly** exchange that has dozens of coins with relatively **high liquidity** and fewer HFT meddling with the order book.

# Storing Limit Order Book Updates in DB

Using a plain PostgreSQL database hosted on Google Cloud SQL with daily backup, I can write a listener to INSERT new updates with ease. For Bittrex, the orderbook updates are ~300 INSERTS/second. For Poloniex, ~30 INSERTS/second. If you are choosing DB now, take a look at [TimescaleDB](https://blog.timescale.com/timescaledb-vs-6a696248104e).

Since it's a websocket related application, NodeJS is an obvious choice. I used TypeScript so code is self-documenting and easier with code hints.

```typescript
import * as pg from 'pg';
const config = require("../config/db.json");

const pool = new pg.Pool(config);

export async function createTableForPair(pair: string) : Promise<boolean> {
  const client = await pool.connect()
  try {
    await client.query(`
    CREATE TABLE IF NOT EXISTS orderbook_${pair}
    (
        id SERIAL PRIMARY KEY NOT NULL,
        seq INTEGER NOT NULL,
        is_trade BOOLEAN,
        is_bid BOOLEAN,
        price DOUBLE PRECISION,
        size DOUBLE PRECISION,
        ts DOUBLE PRECISION,
        trade_id INTEGER,
        type INTEGER
    );
    CREATE UNIQUE INDEX IF NOT EXISTS
      orderbook_${pair}_id_uindex ON orderbook_${pair} (id);

    CREATE TABLE IF NOT EXISTS orderbook_snapshot_${pair}
    (
        id SERIAL PRIMARY KEY NOT NULL,
        seq INTEGER NOT NULL,
        snapshot JSON NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS
      orderbook_snapshot_${pair}_id_uindex ON orderbook_snapshot_${pair} (id);
    `);

  } finally {
    client.release()
  }

  return true;
}

```

Here we are using a connection pool because this software makes frequent queries. Connecting a new client to the PostgreSQL server requires a handshake which can take 20-30 milliseconds. During this time passwords are negotiated, SSL may be established, and configuration information is shared with the client & server. Incurring this cost every time we want to execute a query would substantially slow down our application.

The caveat is that you must always return the client to the pool if you successfully check it out, regardless of whether or not there was an error with the queries you ran on the client. If you don't check in the client your application will leak them and eventually your pool will be empty forever and all future requests to check out a client from the pool will wait forever.

The pool will handle the consumer-producer threading issues.

So we create two tables, one for order book updates and one for orderbook snapshots. The latter is not strictly necessary. The field `seq` is the Nounce because sometimes the websocket can scramble up the order so it's the programmer's job to re-arrange the updates in the right order. Also, we are storing filled trades with order book updates so there is no need to create another table. It's differentiated with `is_trade` field. `ts` is the timestamp. `trade_id` is the internal trade id. Needless to say, the table is index by `id`.

This function is accompanied by `tableExistsForPair`. The script checks if the tables are created during init.

```typescript
async function initTables(markets : string[]) {
    let pairs = markets.map(toPair);

    let create = await Promise.all(
        pairs.map(pair => new Promise(async (resolve, reject) => {
            let exists = await tableExistsForPair(pair);
            if (!exists) {
                console.log(`${pair} table does not exist. Creating...`)
                await createTableForPair(pair);
            }
            resolve(true);
        }))
    );

    console.log("Double checking...");
    let created = await Promise.all(pairs.map(tableExistsForPair));
    for (let i = 0; i < created.length; i++) {
        if (!created[i]) {
            throw `Table for '${pairs[i]}' cannot be created.`;
        }
    }
}
```

We use `await Promise.all()` to concurrently run multiple DB requests instead of serially awaiting each one to finish. You always want to double check failed queries.

# Listen for Updates

First, to add some joy to development, let's get the types of JSON objects emitted defined using TypeScript interface. This is where TypeScript really comes in handy. My only gripe with TypeScript is the lack of a real [bottom](https://wiki.haskell.org/Bottom).

```typescript
export interface ExchangeState {
     H: string, // Hub
     M: "updateExchangeState",
     A: [ExchangeStateUpdate]
}

export type Side = "SELL" | "BUY";
export type UpdateType = 0 // new order entries at matching price, add to orderbook
                       | 1 // cancelled / filled order entries at matching price, delete from orderbook
                       | 2 // changed order entries at matching price (partial fills, cancellations), edit in orderbook
                       ;

export interface ExchangeStateUpdate {
    MarketName: string,
    Nounce: number,
    Buys: [Buy],
    Sells: [Sell],
    Fills: [Fill]
}

export type Sell = Buy;

export interface Buy {
    Type: UpdateType,
    Rate: number,
    Quantity: number
}

export interface Fill {
    OrderType: Side,
    Rate: number,
    Quantity: number,
    TimeStamp: string,
}

//================================

export interface SummaryState {
    H: string,
    M: "updateSummaryState",
    A: [SummaryStateUpdate]
}

export interface SummaryStateUpdate {
    Nounce: number,
    Deltas: [PairUpdate] 
}

export interface PairUpdate {
    MarketName: string,
    High: number
    Low: number,
    Volume: number,
    Last: number,
    BaseVolume: number,
    TimeStamp: string,
    Bid: number,
    Ask: number,
    OpenBuyOrders: number,
    OpenSellOrders: number,
    PrevDay: number,
    Created: string
}

//================================

export interface UnhandledData {
    unhandled_data: {
        R: boolean, // true, 
        I: string,  // '1'
    }
}

//================================
//callbacks

export type ExchangeCallback = (value: ExchangeStateUpdate, index?: number, array?: ExchangeStateUpdate[]) => void 
export type SummaryCallback = (value: PairUpdate, index?: number, array?: PairUpdate[]) => void


//================================
//db updates

export interface DBUpdate {
    pair: string,
    seq: number,
    is_trade: boolean,
    is_bid: boolean,
    price: number,
    size: number,
    timestamp: number,
    type: number
}
```

Next we want to listen to the websocket and dump everything update to the database.

```typescript
// get an array of market names
function allMarkets() : Promise<[string]> {
    return new Promise((resolve, reject) => {
        bittrex.getmarketsummaries( function( data : any, err : never) {
            if (err) reject(err);
            const ret = data.result.map((market : PairUpdate) => market.MarketName)
            resolve(ret);
        });
    });
}

// Formats a JSON object into a DBUpdate object
function formatUpdate(v : ExchangeStateUpdate) : DBUpdate[] {
    let updates : DBUpdate[] = [];
    
    const pair = toPair(v.MarketName);
    const seq = v.Nounce;
    const timestamp = Date.now() / 1000;

    v.Buys.forEach(buy => {
        updates.push(
            {
                pair,
                seq,
                is_trade: false,
                is_bid: true,
                price: buy.Rate,
                size: buy.Quantity,
                timestamp,
                type: buy.Type
            }
        );
    });

    v.Sells.forEach(sell => {
        updates.push(
            {
                pair,
                seq,
                is_trade: false,
                is_bid: false,
                price: sell.Rate,
                size: sell.Quantity,
                timestamp,
                type: sell.Type
            }
        );
    });

    v.Fills.forEach(fill => {
        updates.push(
            {
                pair,
                seq,
                is_trade: true,
                is_bid: fill.OrderType === "BUY",
                price: fill.Rate,
                size: fill.Quantity,
                timestamp: (new Date(fill.TimeStamp)).getTime() / 1000,
                type: null
            }
        );
    })

    return updates;
}

async function watch() {
    try {
        let mkts = await allMarkets()

        await initTables(mkts);
        console.log("Tables created.");

        listen(mkts, (v, i, a) => {
            let updates : DBUpdate[] = formatUpdate(v);
            updates.forEach(update => {
                const { pair, seq, is_trade, is_bid, price, size, timestamp, type } = update;
                saveUpdate(pair, seq, is_trade, is_bid, price, size, timestamp, type);
            });
        });

    } catch (e) {
        console.log(e);
        throw e;
    }
}

let main = watch;

main();
```

To start the program, just call `watch()`. As you can see, this code is highly modular and development was a breeze.

With a copy of the order book securely stored in the database, we can replay and reconstruct the order book at any given moment. Next post will cover order book reconstruction, visualization and unusual discoveries. Stay tuned!
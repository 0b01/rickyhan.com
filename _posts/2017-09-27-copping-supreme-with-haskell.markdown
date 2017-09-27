---
layout: post
title:  "Copping Supreme with Haskell"
date:   2017-09-27 00:37:02 -0400
categories: jekyll update
---

Recently, a friend asked me to write a program that buys things off of a shopping website as soon as anything is added. I decided to write it in Haskell.

Supreme is a fashion brand that curbs supply to create artificial scarcity, which results in higher consumer surplus and resell profit margin. So yes, the deadweight loss suffered in the primary market(webstore) is actually paying for the reseller network effect and virality.

![supreme brick](http://d17ol771963kd3.cloudfront.net/122510/zo/LGlxG_4e95s.jpg)

This script does the following:

1. GET website url.

2. Diff page to determine any changes.

3. If changes are found and within range specified in options, place an order for 100 items.

4. Wait x seconds

5. Repeat

First, the types:

```haskell

type PageHash = String
type PageURL = String
type PageSource = BSL.ByteString

data Task = Task { pageSource :: PageSource
                 , pageHash :: PageHash
                 } deriving (Show, Eq)

data TagType = Open
             | Close
             | TextRegex
             deriving (Show, Eq, Ord)

data Opt = BlackList TagType PageSource
         | WhiteList TagType PageSource
         deriving (Show, Eq, Ord)

type Opts = [Opt]

data URL = URL {
  url :: PageURL,
  opts :: Opts
} deriving (Show, Eq, Ord)

type TaskMap = Map.Map URL Task
```

The idea is to iterate through a list of `URL`s, each with `pageSource` and `pageHash`, and then put each URL-Task pair into a Map. In the main loop, compare the old Map to the new Map. If the difference is on `WhiteList` and not on `BlackList` or fits `TextRegex`, then send a notification and place an order for 100 items. The last part may or may not be implemented.

The implementation is straightforward:

```haskell
{-# LANGUAGE ViewPatterns #-}

module Main where

import Data.IORef (newIORef, readIORef, writeIORef, )
import Control.Monad
import Control.Concurrent (forkIO, threadDelay, )
import qualified Data.Map.Strict as Map

data GlobalState = GlobalState { tasks :: IORef (Map.Map URL Task) }

initialize :: IO GlobalState
initialize = do
  titles <- getPages testURLs
  tasksRef <- newIORef titles
  return GlobalState { tasks = tasksRef }

startTimer :: GlobalState -> IO ()
startTimer (tasks -> ref) = do
  threadId <- forkIO loop
  return ()
  where
    loop = do
      threadDelay $ seconds 1
      oldPages <- readIORef ref
      newPages <- updatePages oldPages
      atomicWriteIORef ref newPages
      print $ getDiffs oldPages newPages
      loop

seconds :: Num a => a -> a
seconds = (*) 1000000

updatePages :: TaskMap -> IO TaskMap
updatePages = getPages . Map.keys

getPages :: [URL] -> IO TaskMap
getPages urls = do
  tasks <- mapM urlToTask urls
  return $ Map.fromList $ zip urls tasks

testURLs :: [URL]
testURLs = [
             URL { url = "http://www.supremenewyork.com/shop/jackets/lnmg0t87f/oytwvb5k8"
                 , opts = [
                            BlackList Open "meta"
                          ]
                 }
           ]

main :: IO ()
main = do
  st <- initialize
  startTimer st
```

Although functional programming discourages mutable states, sometimes mutable variables are needed. First, `getPages` and initialize the task map, and store it in memory using `IORef` which operates inside `IO` monad to stay perfectly functional. Then in the future, update the reference to the new map. 

`ViewPatterns` feature flag allows pattern matching on records fields for easy access of data inside (in this case `IORef`).

Now there are 2 holes yet to be implemented.

* `urlToTask`
  
  Does what it says, `URL` in, send requests and hash page source, `Task` out.

* `getDiffs`
  
  Checks diffs.

```
import qualified Network.Wreq as Wreq
import Control.Lens
import Data.IORef
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as BSL
import qualified Crypto.Hash as H
import qualified Data.Algorithm.Diff
import qualified Data.Map.Strict as Map
import qualified Text.HTML.TagSoup as TS


fetchPage :: String -> IO (Maybe PageSource)
fetchPage url = do
  r <- Wreq.get url
  return $ r ^? Wreq.responseBody

hexSha3_512 :: BS.ByteString -> PageHash
hexSha3_512 bs = show (H.hash bs :: H.Digest H.SHA1)

pageToHash :: BSL.ByteString -> PageHash
pageToHash page = do
  let strictBS = BSL.toStrict page
  hexSha3_512 strictBS

urlToTask :: URL -> IO Task
urlToTask URL {url=url, opts=opts}= do
  pageSource <- fetchPage url
  case pageSource of
    Just source -> return Task { pageSource = source
    	                       , pageHash = pageToHash source
    	                       , pageOpts = opts
    	                       }
```

Nothing to see here. Wreq is the HTTP library whose results can be accessed using Lens. Hash `responseBody` for later use and store source, hash, and opts in `Task` record.

Here is the implementation for the `getDiff` method(in a separate module).

```
{-# LANGUAGE OverloadedStrings #-}

module Diff where

import Lib
import Control.Monad
import qualified Data.Algorithm.Diff as D
import qualified Data.Algorithm.DiffOutput as D
import qualified Data.Map.Strict as Map
import qualified Text.HTML.TagSoup as TS
import Debug.Trace
import Text.Regex.PCRE

getDiffs :: TaskMap -> TaskMap -> Map.Map URL (Maybe Bool)
getDiffs olds news = Map.mapWithKey diff olds
  where
    diff key oldTask = do
      newTask <- Map.lookup key news

      let hash  = pageHash oldTask
      let hash' = pageHash newTask

      let diffs = D.getDiff (parsedSource oldTask) (parsedSource newTask)
      let options = opts key
      let filteredDiffs = filtered options diffs

      let changed = (hash /= hash') && (not.null $ filteredDiffs)
      if changed
        then traceM $ ppDiff filteredDiffs
        else traceM "Nothing changed"
      return changed

parsedSource :: Task -> [TS.Tag PageSource]
parsedSource = TS.parseTags . pageSource

ppDiff :: [D.Diff (TS.Tag PageSource)] -> String
ppDiff = unlines . ppDiffPairs

ppDiffPairs :: [D.Diff (TS.Tag PageSource)] -> [String]
ppDiffPairs diffs = zipWith
      (\(D.First first) (D.Second second) ->
         "<<<<<<\n"
      ++ show first
      ++ "\n======\n"
      ++ show second
      ++ "\n>>>>>>\n"
      )
    (onlyFirsts diffs) (onlySeconds diffs)

onlySeconds :: [D.Diff t] -> [D.Diff t]
onlySeconds = filter (\diff ->
  case diff of
    D.Second _ -> True
    _         -> False)

onlyFirsts :: [D.Diff t] -> [D.Diff t]
onlyFirsts = filter (\diff ->
  case diff of
    D.First _ -> True
    _         -> False)

filtered :: Opts -> [D.Diff (TS.Tag PageSource)] -> [D.Diff (TS.Tag PageSource)]
filtered options diffs = filter(\diff -> all (\option -> ok option diff) options ) diffs
  where ok option diff = case diff of D.Both _ _ -> False
                                      _          -> case option of BlackList Open name -> not $ TS.isTagOpenName name d
                                                                   BlackList Close name -> not $ TS.isTagCloseName name d
                                                                   BlackList TextRegex regex -> TS.isTagText d && (TS.fromTagText d =~ regex)
                                                                   WhiteList Open name -> name == "*" || TS.isTagOpenName name d
                                                                   _ -> undefined
                                                                   where d = fromDiff diff

fromDiff :: D.Diff (TS.Tag PageSource) -> TS.Tag PageSource
fromDiff (D.First a) = a
fromDiff (D.Second a) = a
```

Most of the logic is in getDiffs: first compare the new hash with the old hash. If `pageSource` changed, then find the difference of the pages at the level of HTML tags. To do this, TagSoup is used to parse page source into a list of Tags. Since the Tags are in the `Eq` typeclass, it is supported by the diff algorithm. This is where the typeclass system becomes really useful.

Now that the diffs are calculated, just need to filter out the ones we said we wanted in options. Since options are implemented on the type level as opposed to data level, pattern matching against types is needed. `Options` is a product type which is pleasant to pattern match against.

# Conclusion

Using Haskell, we can monitor pages in a highly modular and type safe manner.

After reading about Supreme drops online, I realized the website only changes on Thursdays so I won't know what to watch.

Later, I lost interest in fashion and this project is abandoned.

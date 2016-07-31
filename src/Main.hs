{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}

import React.Flux

import Control.Monad.Random
import Control.Monad.State
import Control.Monad.Except
import Data.List
import qualified Data.Text as T

import Data.Typeable (Typeable)

data Color = Red | Green | Blue deriving (Enum, Eq)
instance Show Color where
  show Red = "R"
  show Green = "G"
  show Blue = "B"

data Number = One | Two | Three deriving (Enum, Eq)
instance Show Number where
  show One = "1"
  show Two = "2"
  show Three = "3"

data Shape = Circle | Diamond | Box deriving (Enum, Eq)
instance Show Shape where
  show Circle = "o"
  show Diamond = "d"
  show Box = "b"

data Fill = Empty | Half | Full deriving (Enum, Eq)
instance Show Fill where
  show Empty = "C"
  show Half = "E"
  show Full = "O"

data Card = Card {
    cardColor :: Color
  , cardNumber :: Number
  , cardShape :: Shape
  , cardFill :: Fill
  } deriving (Eq, Typeable)

instance Show Card where
  show (Card c n s f) = "(" ++ show c ++ " " ++ show n ++ " " ++ show s ++ " " ++ show f ++ ")"

instance Bounded Card where
  minBound = (toEnum cardMinBound)
  maxBound = (toEnum cardMaxBound)

cardMinBound = 0
cardMaxBound = 80

data Game = Game {
    gameAll :: [Card]
  , gameDealt :: [Card]
  , gameConsumed :: [Card]
  }

instance Show Game where
  show (Game a (a1:a2:a3:a4:b1:b2:b3:b4:c1:c2:c3:c4:d1:d2:d3:d4:[]) c) =
    show a1 ++ " " ++ show a2 ++ " " ++ show a3 ++ " " ++ show a4 ++ "\n" ++
    show b1 ++ " " ++ show b2 ++ " " ++ show b3 ++ " " ++ show b4 ++ "\n" ++
    show c1 ++ " " ++ show c2 ++ " " ++ show c3 ++ " " ++ show c4 ++ "\n" ++
    show d1 ++ " " ++ show d2 ++ " " ++ show d3 ++ " " ++ show d4 ++ "\n"

instance Enum Card where
  toEnum i = if i >= 0 && i < 81
                then allCards !! i
                else error $ "toEnum{Game}: tag (" ++ show i ++ ") is outside of enumeration's range (" ++ show cardMinBound ++ ", " ++ show cardMaxBound ++ ")"
  fromEnum c = case findIndex (==c) allCards of
                 Nothing -> error $ "fromEnum{Game}: Card does not exist: " ++ show c
                 (Just i) -> i

allCards = [Card c n s f
              | c <- [Red .. Blue],
                n <- [One .. Three],
                s <- [Circle .. Box],
                f <- [Empty .. Full]]

initGame :: (MonadRandom m) => m Game
initGame = do
  dealt <- getDealt
  return $ Game allCards dealt []
     where getDealt :: (MonadRandom m) => m [Card]
           getDealt = do
             d <- (map toEnum) `fmap` randomList 16
             if null $ filter isSolution (allCombinations d)
                then getDealt
                else return d

-- logic

isSolution :: (Card, Card, Card) -> Bool
isSolution ((Card c1 n1 s1 f1), (Card c2 n2 s2 f2), (Card c3 n3 s3 f3)) =
    m (fromEnum c1) (fromEnum c2) (fromEnum c3)
  && m (fromEnum n1) (fromEnum n2) (fromEnum n3)
  && m (fromEnum s1) (fromEnum s2) (fromEnum s3)
  && m (fromEnum f1) (fromEnum f2) (fromEnum f3)
    where m x1 x2 x3 = ((x1 == x2) && (x2 == x3))
                     || ((x1 /= x2) && (x2 /= x3) && (x1 /= x3))

allCombinations :: Enum a => [a] -> [(a, a, a)]
allCombinations [] = []
allCombinations (x:[]) = []
allCombinations xs = [(xs !! x, xs !! y, xs !! z) | x <- [0 .. length xs - 3 ], y <- [succ x..length xs - 2], z <- [succ y.. length xs - 1]]
solutions xs = filter isSolution (allCombinations xs)

-- test data

testsolutions :: [(Card, Card, Card)]
testsolutions = [ (Card Red One Diamond Full, Card Green Two Diamond Full, Card Blue Three Diamond Full)
                , (Card Blue One Diamond Half, Card Blue One Circle Empty, Card Blue One Box Full)]

testNonSolutions :: [(Card, Card, Card)]
testNonSolutions = [ (Card Red One Diamond Full, Card Red One Box Empty, Card Green Two Box Empty),
                     (Card Green One Diamond Full, Card Green One Diamond Empty, Card Green Two Diamond Empty) ]


-- Util

newNumber :: (MonadRandom m, MonadState [Int] m) => m ()
newNumber = do
  d <- get
  n <- getRandomR (0, 80)
  if n `elem` d
     then newNumber
     else put (n:d)

randomList :: MonadRandom m => Int -> m [Int]
randomList n = execStateT (sequence $ replicate n newNumber) []

-- react-flux
cardsApp :: ReactView Game
cardsApp = defineControllerView "cards app" cardsStore $ \cardState g ->
  div_ $ do
    h1_ "Welcome to cards game. This is cards game."
    svg_ (mapM_ card_ $ gameDealt g)

card :: ReactView Card
card = defineView "card" $ \c ->
  case c of
    Card c n Diamond f -> diamond_ c f n
    Card c n Box f -> box_ c f n
    Card c n Circle f -> Main.circle_ c f n

diamond :: Color -> Fill -> Number -> ReactView ()
diamond c f n = defineView "diamond" $ \() ->
    g_ [ "className" @= show Diamond
       , "color" @= show c
       , "fill" @= show f
       , "number" @= show n] (text_ $ elemText $ T.pack $ "DIAMOND" ++ show c ++ show f ++ show n)

diamond_ :: Color -> Fill -> Number -> ReactElementM eventHandler ()
diamond_ c f n = view (diamond c f n) () mempty

circle :: Color -> Fill -> Number -> ReactView ()
circle c f n = defineView "circle" $ \() ->
    g_ [ "className" @= show Circle
       , "color" @= show c
       , "fill" @= show f
       , "number" @= show n] (React.Flux.circle_ ["r" $= "40"] "test")

circle_ :: Color -> Fill -> Number -> ReactElementM eventHandler ()
circle_ c f n = view (circle c f n) () mempty

box :: Color -> Fill -> Number -> ReactView ()
box c f n = defineView "box" $ \() ->
    g_ [ "className" @= show Box
       , "color" @= show c
       , "fill" @= show f
       , "number" @= show n] (text_ $ elemText $ T.pack $ "BOX" ++ show c ++ show f ++ show n)

box_ :: Color -> Fill -> Number -> ReactElementM eventHandler ()
box_ c f n = view (box c f n) () mempty


card_ :: Card -> ReactElementM eventHandler ()
card_ !c = view card c mempty

-- game :: ReactView Game
-- game = defineView "game" $ \(Game _ d _) ->
    -- mapM_ (div_ >>= card) d

-- TODO Make ReactStore an instance of MonadRandom
cardsStore :: ReactStore Game
cardsStore = do
  let g = runRand initGame (mkStdGen 0)
  mkStore $ fst g

data GameAction = GameCreate

instance StoreData Game where
  type StoreAction Game = GameAction
  transform action (Game a d c) = do
    newGame <- case action of
                 GameCreate -> initGame
    return newGame

-- main
main :: IO ()
main = do
  g <- initGame
  putStrLn $ show g
  reactRender "flux-test" cardsApp g


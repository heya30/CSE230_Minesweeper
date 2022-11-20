{-# LANGUAGE OverloadedStrings #-}
module Game where

import Prelude
import Brick.AttrMap
import Brick.Main
import Brick.Types
import Brick.Widgets.Core

import Data.List
import Graphics.Vty.Attributes
import Graphics.Vty.Input.Events
import System.Random
import System.Random (Random(..), newStdGen)
import System.IO.Unsafe
import System.Random (newStdGen, randomRs)
type BoardSize = Int
type JewelSize = Int
type JewelVal = Int

data Difficulty = Easy | Medium | Hard
    deriving (Eq, Show)

data Direction = DirUp | DirDown | DirLeft | DirRight
    deriving (Eq, Show)

data Block = Block
    {
        val::JewelVal
    }
    deriving (Eq, Show)


type Board = [Row]

type Row = [Block]

data State = State
    {
        board::Board,
        score::Int,
        selected::Bool,
        row::Int,
        col::Int,
        seed::Int
    }
    deriving (Eq, Show)

type ResourceName = String

testBoard :: [[Block]]
testBoard = initBoardValue 3 3

initBoardValue :: BoardSize -> JewelSize -> [[Block]]
initBoardValue bsize jsize = replicate bsize (replicate bsize Block {val = 1})

initBoard :: BoardSize -> JewelSize -> Board -- TODO: generate board by bsize and jsize
initBoard bsize jsize = initBoardValue bsize jsize


shuffleBoard :: State -> State
shuffleBoard s = s -- TODO

drawState :: State -> [Widget ResourceName] -- TODO: also show score, etc.
drawState st = drawBoard (board st) (row st) (col st)

drawBoard :: Board -> Int -> Int -> [Widget ResourceName]
drawBoard bd row col = [vBox $ drawBoardHelper bd row col]

drawBoardHelper :: Board -> Int -> Int -> [Widget ResourceName]
drawBoardHelper bd row col = case bd of
                                [] -> []
                                x:xs -> if row == 0
                                            then (drawRow x col) : (drawBoard xs (-1) col)
                                            else (drawRow x (-1)) : (drawBoard xs (row - 1) col)

drawRow :: Row -> Int -> Widget n
drawRow r col = if col < 0
                    then hBox $ map drawBlock r
                    else hBox $ drawRowSelected r col

drawRowSelected :: Row -> Int -> [Widget n]
drawRowSelected r col = case r of
                            [] -> []
                            x:xs -> if col == 0
                                        then (drawBlockSelected x) : (drawRowSelected xs (-1))
                                        else (drawBlock x) : (drawRowSelected xs (col - 1))

drawBlock :: Block -> Widget n
drawBlock blk = str (show (val blk) ++ "  ") -- TODO

drawBlockSelected :: Block -> Widget n
drawBlockSelected blk = str (show (val blk) ++ "< ") -- TODO

initGame :: Difficulty -> IO State -- TODO
initGame diff = let iBoard = initBoard 10 3 in
                let init = State {board = iBoard, score = 0, selected = False, row = 0, col = 0, seed=33} in
                let iState = ((cancelBlocks init) {score =0}) in
                do 
                   _ <- defaultMain jLApp iState
                   return iState

jLApp :: App State e ResourceName
jLApp = App 
        {
            appDraw = drawState,
            appChooseCursor = showFirstCursor,
            appHandleEvent = handleSelectEvent,
            appStartEvent = pure,
            appAttrMap = const $ attrMap mempty []
        }

handleSelectEvent :: State -> BrickEvent n e -> EventM n (Next State)
handleSelectEvent s e =
    case e of 
        VtyEvent vtye -> 
            case vtye of
                EvKey (KChar 'a') [] -> continue $ (cancelBlocks s)
                EvKey (KEsc) [] -> halt s
                EvKey (KChar 's') [] -> continue $ (shuffleBoard s)
                EvKey (KEnter) [] -> continue $ s {selected = True}
                EvKey (KUp) [] -> continue $ (handleDirection s DirUp)
                EvKey (KDown) [] -> continue $ (handleDirection s DirDown)
                EvKey (KLeft) [] -> continue $ (handleDirection s DirLeft)
                EvKey (KRight) [] -> continue $ (handleDirection s DirRight)
                _ -> continue s
        _ -> continue s

handleDirection :: State -> Game.Direction -> State
handleDirection s d = case selected s of
                        True -> let newState = cancelBlocks (swapByDir s d) in
                                if score newState > score s
                                    then newState
                                    else s
                        False -> moveCursor s d

moveCursor :: State -> Game.Direction -> State
moveCursor s d = case d of
                    DirUp -> if row s > 0
                                then s {row = (row s) - 1}
                                else s
                    DirDown -> if row s < length (board s) - 1
                                then s {row = (row s) + 1}
                                else s
                    DirLeft -> if col s > 0
                                then s {col = (col s) - 1}
                                else s
                    DirRight -> if col s < length (head (board s)) - 1
                                then s {col = (col s) + 1}
                                else s

swapByDir :: State -> Game.Direction -> State
swapByDir s d = let b = board s
                    r = row s
                    c = col s
                    newR = row (moveCursor s d)
                    newC = col (moveCursor s d) in
                s {board = swapBlock b r c newR newC, selected = False}
                            
swapBlock :: Board -> Int -> Int -> Int -> Int -> Board
swapBlock b row1 col1 row2 col2 = [[get r c x | (c, x) <- zip [0..length temp - 1] temp] | (r, temp) <- zip [0..length b - 1] b]
                                    where get r c x | (r == row1) && (c == col1) = (b !! row2) !! col2
                                                    | (r == row2) && (c == col2) = (b !! row1) !! col1
                                                    | otherwise = x

cancelBlocks :: State -> State
cancelBlocks s = 
    let oldBoard = board s in
        let removeBoard = (removeBlock oldBoard) in
            let newScore = (eliminatedNum removeBoard)
                newBoard = (addNewBlocks(downBlock(removeBoard)) (seed(s))) in
                if (newScore == 0)
                    then s {selected = False}
                    else (cancelBlocks s {board = newBoard, score = (score (s) + newScore), 
                                            selected = False, seed=newScore+seed(s)})
              


-- TODO: may rewrite by using mapWithIndex
removeBlock :: [[Block]] -> [[Block]]
removeBlock board = zipWith f [0..] board
          where 
            f  j row = zipWith3 f' (replicate (length row) j) [0..] row
            f' i j x = if ifBlockEliminable board (i) (j)
                        then Block {val = -1}
                        else x

eliminatedNum :: [[Block]] -> Int
eliminatedNum board = foldr f 0 board
    where f x acc =  (f' x) + acc
          f' :: [Block] -> Int
          f' = foldr (\x n -> if x == Block {val = -1} then n+1 else n) 0


addNewBlocks :: [[Block]] -> Int -> [[Block]]
addNewBlocks board seed = zipWith f [0..] board
          where 
            f  j row = zipWith3 f' (replicate (length row) j) [0..] row
            f' i j x = if val(x) == -1
                        then Block {val = (makeRandomInt (seed+10*i+5*j))}
                        else x

makeRandomInt::Int -> Int
makeRandomInt seed = do
  let gen = mkStdGen seed
  fst $ randomR (1, 5) gen



downBlock :: [[Block]] -> [[Block]]
downBlock block = transpose((transpose(transpose(map leftRow (transpose block)))))

mergeRow :: [Block] -> [Block]
mergeRow row = case row of
  x:xs -> if val(x) == -1 then mergeRow xs else x:(mergeRow xs)
  [] -> []

leftRow :: [Block] -> [Block]
leftRow row = (replicate ((length row) - (length x)) (Block {val = -1})) ++ x 
  where x = mergeRow row

leftBlock :: [[Block]] -> [[Block]]
leftBlock g = map leftRow g
       

ifBlockEliminable :: [[Block]] -> Int -> Int -> Bool
ifBlockEliminable board row column = matchInRow board row column
    || matchInRow (transpose board) column row


matchInRow :: [[Block]] -> Int -> Int -> Bool
matchInRow board row column = 
    (isSameBlk board row (column-1) row column) && (isSameBlk board row column row (column+1))
    || (isSameBlk board row (column-1) row (column-2)) && (isSameBlk board row column row (column-1))
    || (isSameBlk board row (column+1) row (column+2)) && (isSameBlk board row column row (column+1))


isSameBlk :: [[Block]] -> Int -> Int -> Int -> Int-> Bool
isSameBlk board r1 c1 r2 c2 = (val (getBlock board r1 c1 )) == (val (getBlock board r2 c2))


getBlock :: [[Block]] -> Int -> Int -> Block
getBlock board row column
    | (column < 0 || row < 0 || row >= (length board) || column >= (length (board!!0))) = Block {val = -1}
    | otherwise = (board !! row) !! column

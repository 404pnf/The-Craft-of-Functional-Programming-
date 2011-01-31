module Chat where

import Network.Socket
import System
import System.IO
import Control.Exception
import Control.Concurrent
import Control.Concurrent.Chan
import Control.Monad
import Time 
import Char (isDigit) 

type Message = (Int, String)
 
main :: IO ()
main = do
    chan <- newChan
    sock <- socket AF_INET Stream 0
    setSocketOption sock ReuseAddr 1
    bindSocket sock (SockAddrInet 1125 iNADDR_ANY)
    listen sock 2
    forkIO (forever (do
        (_, msg) <- readChan chan
        return()))
    mainLoop sock chan 0
 
mainLoop :: Socket -> Chan Message -> Int -> IO ()
mainLoop sock chan n = do
    conn <- accept sock
    forkIO (runConn conn chan n)
    mainLoop sock chan $! n+1
 
runConn :: (Socket, SockAddr) -> Chan Message -> Int -> IO ()
runConn (sock, _) chan n = do
    let sendAll msg = writeChan chan (n, msg)
    hdl <- socketToHandle sock ReadWriteMode
    hSetBuffering hdl NoBuffering
    hPutStrLn hdl ("You are user number " ++ show n ++ ".")
    sendAll ("User number " ++ show n ++ " entered.")
    logOnT <- getClockTime
    chan' <- dupChan chan
    reader <- (forkIO (forever (do
        (n', line) <- readChan chan'
        when (n /= n') $ hPutStrLn hdl line)))
    handle (\e -> exitWith e) $ forever $ do
        line <- liftM init (hGetLine hdl)
        now <- getClockTime
        case line of
          "$\\SinceLogOn" -> do 
            hPutStrLn hdl (show (diffClockTimes logOnT now))
          "$\\Time" -> do
            hPutStrLn hdl (show now)
          ('$':'\\':'s':x) -> do
            let sIDNum = takeWhile isDigit x
            let sMsg = dropWhile (/=' ') x
            let sHead = "This is a secret from " ++ sIDNum ++ ":"
            let s = sHead ++ sMsg
            case sIDNum of 
              "" -> do
               hPutStrLn hdl "It is not a secret."
              _ -> do
               let sn = (read sIDNum :: Int)
               when (sn /= n) $ writeChan chan' (sn, s)
          ('$':'\\':_) -> do
            hPutStrLn hdl "We'll miss you."
            killThread reader
            sendAll ("User " ++ show n ++ " left.")
            hClose hdl
            exitWith ExitSuccess
          _  -> do
            sendAll ("UserID" ++ show n ++ ": " ++ line)


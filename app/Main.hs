{-# LANGUAGE OverloadedStrings #-}

module Main where

--------------------------------------------------------------------------------
--Imports

import qualified Data.Text as T
import qualified Data.ByteString.Char8 as B

import Data.Functor
import Data.List

import Network.HTTP.Types                   --useful http types
import Network.Wai                          --(web server <--> web app/framework) interface... so this is just a terribly basic web application?
import Network.Wai.Handler.Warp             --warp fast low level web server

import Data.List.Split (splitOn)
import System.Directory (doesFileExist)

--------------------------------------------------------------------------------
--Types

type Extension = String

--------------------------------------------------------------------------------
--Top Level App Functions

main :: IO ()
main = runWarp 3000 application

runWarp :: Port -> Application -> IO ()
runWarp port app = putStrLn ("Listening on port: " ++ show port) >> run port app

application :: Application
application = (>>=) . handle

--------------------------------------------------------------------------------
--Handler

handle :: Request -> IO Response
handle request =
  if requestMethod request /= methodGet
  then return $ responseLBS status500 [] ""
  else do
    let filePath = getPath request
        extension = getExtension filePath
    fileExists <- doesFileExist filePath
    if fileExists
    then return $ responseFile status200 [("Content-Type", B.pack $ mimeType $ extension)] filePath Nothing
    else if extension == "html"
         then return $ responseFile status404 [("Content-Type", B.pack $ mimeType $ extension)] "public/404.html" Nothing
         else return $ responseLBS status404 [] ""

--------------------------------------------------------------------------------
--Helper Functions

getPath :: Request -> FilePath
getPath request = case tail $ B.unpack $ rawPathInfo request of
  "" -> "public/index.html"
  filePath -> "public/" ++ filePath ++ if '.' `elem` filePath then "" else ".html"

mimeType :: Extension -> String
mimeType filePath = case filePath of
  "html" -> "text/html"
  "css" -> "text/css"
  "js" -> "application/javascript"
  "json" -> "application/json"
  "txt" -> "text/plain"
  "svg" -> "image/svg+xml"
  _ -> "application/octet-stream"

getExtension :: FilePath -> Extension
getExtension = last . splitOn "."

--------------------------------------------------------------------------------

{-
All messages carry:
  HTTP Headers
  HTTP Body (this can be empty and often consists of the contents of a retrieved file or a ByteString generated by the server)
-}

{-
HTTP Headers are split into 4 categories:
  -General (Date, Cache-Control, Connection)
  -Request (Accept, Cookie)
  -Response (Age, Location, Server)
  -Entity (Content-Type, Content-Length, Content-Encoding)      /** This is information specific to the HTTP Body **/
-}

{-
Requests carry:
  HTTP Method
  URL Path
  Query String
  HTTP Version
  Whether Connection Is Secure
  Client Host Information
-}

{-
Responses carry: HTTP Status Code
-}

--------------------------------------------------------------------------------

{-
This is intended to be a static server which responds specifically to GET Requests
for files located in the Public folder.

The process for recieving a request is as follows:
-Check if it's a GET request, else return error 500 with "Content-Length" as "0"
-Take path and if "" then index, if missing a file extension, append ".html", then add "public/"
-Take new path and check whether it attempts to access a file outside of "public" folder, if so error forbidden contentlength 0
-Take new path and check whether it matches a file, if not, check if .html was file extension and return notfound with body as 404 page otherwise return 404 with no body
-If it does match that file return 200 with that file as the body and Content type and content length set

  TODO: Add security to prevent people from "/../"ing out of the public folder

-}

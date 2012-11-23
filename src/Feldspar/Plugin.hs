{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ForeignFunctionInterface #-}

module Feldspar.Plugin where

import Feldspar.Plugin.Generic
import Feldspar.Plugin.Utils
import Feldspar.Plugin.Marshal

import Debug.Trace

import System.Plugins

import Foreign.Ptr
import Foreign.Marshal (alloca)
import Foreign.Marshal.Unsafe (unsafeLocalState)
import Foreign.Storable (Storable(peek))
import Foreign.C.String (CString, withCString)

import Control.Monad ((>=>), when, unless)

import Language.Haskell.TH
import Language.Haskell.TH.Syntax (sequenceQ)

import System.Directory (doesFileExist, removeFile, createDirectoryIfMissing)
import System.Process (readProcessWithExitCode)


-- Feldspar specific
import Feldspar.Compiler.Internal (icompileWithInfos)
import Feldspar.Compiler.Compiler
import Feldspar.Compiler.Backend.C.Library (fixFunctionName)

defaultConfig = Config { declWorker   = declareWorker
                       , typeFromName = loadFunType >=> rewriteType
                       , prefix       = "c_"
                       , wdir         = "tmp"
                       , opts         = [ "-package feldspar-compiler"
                                        , "-optc -std=c99"
                                        , "-c"
                                        , "-optc -Wall"
                                        , "-w"
                                        ]
                       }

loadFun = loadFunWithConfig defaultConfig


declareImport :: Name -> TypeQ -> DecQ
declareImport name typ =
    forImpD cCall safe "dynamic" name [t|FunPtr $typ -> $typ|]

declareWorker :: Config -> Name -> Name -> [Name] -> Type -> [DecQ]
declareWorker conf@Config{..} wname name as typ =
    [ declareImport factory csig
    , funD bname [clause [] (builder conf name) []]
    , sigD wname hsig
    , funD wname [clause (varsP as) (worker bname factory as csig) []]
    ]
  where
    base    = nameBase name
    bname   = mkName $ prefix ++ base ++ "_builder"
    factory = mkName $ prefix ++ base ++ "_factory"
    varsP   = map varP
    hsig    = buildHaskellType typ
    csig    = buildCType typ

worker :: Name -> Name -> [Name] -> Q Type -> Q Body
worker bname factory as csig = normalB
    [|do
        let ptr               = $(varE bname)
        let funptr            = castPtrToFunPtr ptr :: FunPtr $csig
        let fun               = $(varE factory) funptr
        alloca $ \outPtr -> do
          $(appE (appsE ([|fun|] : map toRef as)) [|outPtr|])
          from =<< peek outPtr
    |]
  where
    toRef name = [| ref $ to $(varE name) |]

builder :: Config -> Name -> Q Body
builder Config{..} fun = let base      = nameBase fun
                             basename  = wdir ++ "/" ++ base
                             hfilename = basename ++ ".h"
                             cfilename = basename ++ ".c"
                             ofilename = basename ++ ".o"
                             pname     = fixFunctionName base
                          in normalB
  [|unsafeLocalState $ do
      createDirectoryIfMissing True wdir
      let result    = $(varE 'icompileWithInfos) $(varE fun) base defaultOptions
      let header    = sctccrHeader result
      let source    = sctccrSource result
      writeFile hfilename $ sourceCode header
      writeFile cfilename $ unlines [ "#include \"" ++ base ++ ".h\"" -- TODO this should really be done by the compiler
                                    , sourceCode source
                                    ]
      compileAndLoad cfilename ofilename opts
      mptr <- withCString ("_" ++ pname) lookupSymbol
      when (mptr == nullPtr) $ error $ "Symbol " ++ pname ++ " not found"
      return mptr
  |]

compileAndLoad :: String -> String -> [String] -> IO ()
compileAndLoad cname oname opts = do
    initLinker
    exists <- doesFileExist oname
    when exists $ removeFile oname
    compileC cname oname opts
    loadRawObject oname
    resolveObjs $ error $ "Symbols in " ++ oname ++ " could not be resolved"

compileC :: String -> String -> [String] -> IO ()
compileC srcfile objfile opts = do
  (excode,stdout,stderr) <- readProcessWithExitCode "ghc" (opts ++ [srcfile]) ""
  let output = stdout ++ stderr
  unless (null output) $ putStrLn output

foreign import ccall safe "lookupSymbol"
   lookupSymbol :: CString -> IO (Ptr a)


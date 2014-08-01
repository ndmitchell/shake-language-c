-- Copyright 2012-2014 Samplecount S.L.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

{-# LANGUAGE TemplateHaskell #-}

module Shakefile.C.Rules (
    Env
  , defaultEnv
  , buildPrefix
  , executable
  , staticLibrary
  , sharedLibrary
  , dynamicLibrary
) where

import           Control.Applicative ((<$>))
import           Control.Monad
import           Development.Shake hiding (Env)
import           Development.Shake.FilePath
import           Development.Shake.Util (parseMakefile)
import           Shakefile.C.BuildFlags as BuildFlags
import           Shakefile.C.Language (languageOf)
import           Shakefile.C.ToolChain as ToolChain
import           Shakefile.C.Util
import           Shakefile.Label (get, mkLabel)
import           Shakefile.SourceTree (SourceTree)
import qualified Shakefile.SourceTree as SourceTree

data Env = Env {
    _buildPrefix :: FilePath
  } deriving (Show)

mkLabel ''Env

defaultEnv :: Env
defaultEnv = Env "."

dependencyFile :: ToolChain -> BuildFlags -> FilePath -> [FilePath] -> FilePath -> Rules ()
dependencyFile toolChain buildFlags input deps output = do
    output ?=> \_ -> do
        need $ [input] ++ deps
        command_ [] (tool compilerCmd toolChain)
                $  concatMapFlag "-I" (get systemIncludes buildFlags)
                ++ mapFlag "-iquote" (get userIncludes buildFlags)
                ++ defineFlags buildFlags
                ++ get preprocessorFlags buildFlags
                ++ compilerFlagsFor (languageOf input) buildFlags
                ++ ["-MM", "-o", output, input]

parseDependencies :: String -> [FilePath]
parseDependencies = snd . head . parseMakefile

type ObjectRule = ToolChain -> BuildFlags -> FilePath -> [FilePath] -> FilePath -> Rules ()

staticObject :: ObjectRule
staticObject toolChain buildFlags input deps output = do
    let depFile = output <.> "d"
    dependencyFile toolChain buildFlags input deps depFile
    output ?=> \_ -> do
        deps' <- parseDependencies <$> readFile' depFile
        need $ [input] ++ deps ++ deps'
        command_ [] (tool compilerCmd toolChain)
                $  concatMapFlag "-I" (get systemIncludes buildFlags)
                ++ mapFlag "-iquote" (get userIncludes buildFlags)
                ++ defineFlags buildFlags
                ++ get preprocessorFlags buildFlags
                ++ compilerFlagsFor (languageOf input) buildFlags
                ++ ["-c", "-o", output, input]

sharedObject :: ObjectRule
sharedObject toolChain = staticObject toolChain -- Disable for now: . append compilerFlags [(Nothing, ["-fPIC"])]

mkObjectsDir :: Env -> FilePath -> FilePath
mkObjectsDir env path = get buildPrefix env </> map tr (makeRelative "/" path) ++ "_obj"
    where tr '.' = '_'
          tr x   = x

mkBuildPath :: Env -> FilePath -> FilePath
mkBuildPath env path = get buildPrefix env </> makeRelative "/" path

buildProduct :: ObjectRule -> Linker -> FilePath
             -> Env -> ToolChain
             -> SourceTree BuildFlags
             -> Rules FilePath
buildProduct object link fileName env toolChain sources = do
    let resultPath = mkBuildPath env fileName
        objectsDir = mkObjectsDir env fileName
        sources' = SourceTree.flags (get ToolChain.defaultBuildFlags toolChain) sources
    objects <- forM (SourceTree.apply BuildFlags.defaultBuildFlags sources') $ \(buildFlags, (src, deps)) -> do
        let obj = objectsDir </> makeRelative "/" (src <.> "o")
        object toolChain buildFlags src deps obj
        return obj
    resultPath ?=> link toolChain (SourceTree.collect BuildFlags.defaultBuildFlags sources') objects
    return resultPath

-- | Rule for building an executable.
executable :: Env -> Target -> ToolChain -> String -> SourceTree BuildFlags -> Rules FilePath
executable env _ toolChain name sources =
    buildProduct
        staticObject
        (get linker toolChain Executable)
        (get linkResultFileName toolChain Executable name)
        env toolChain sources

-- | Rule for building a static library.
staticLibrary :: Env -> Target -> ToolChain -> String -> SourceTree BuildFlags -> Rules FilePath
staticLibrary env _ toolChain name sources =
    buildProduct
        staticObject
        (get archiver toolChain)
        (get archiveFileName toolChain name)
        env toolChain sources

-- | Rule for building a shared library.
sharedLibrary :: Env -> Target -> ToolChain -> String -> SourceTree BuildFlags -> Rules FilePath
sharedLibrary env _ toolChain name sources =
    buildProduct
        sharedObject
        (get linker toolChain SharedLibrary)
        (get linkResultFileName toolChain SharedLibrary name)
        env toolChain sources

-- | Rule for building a dynamic library.
dynamicLibrary :: Env -> Target -> ToolChain -> String -> SourceTree BuildFlags -> Rules FilePath
dynamicLibrary env _ toolChain name sources =
    buildProduct
        sharedObject
        (get linker toolChain DynamicLibrary)
        (get linkResultFileName toolChain DynamicLibrary name)
        env toolChain sources
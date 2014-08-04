-- Copyright 2012-2013 Samplecount S.L.
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

module Shakefile.C.Host (
    OS(..)
  , os
  , onlyOn
  , notOn
  , executableExtension
  , sharedLibraryExtension
  , loadableLibraryExtension
  , getDefaultToolChain
) where

import           Shakefile.C (Target, ToolChain, notIf, onlyIf)
import qualified Shakefile.C.Linux as Linux
import qualified Shakefile.C.OSX as OSX
import qualified Shakefile.C.Windows as Windows
import qualified System.Info as System

-- | Host operating system.
data OS =
    Linux
  | OSX
  | Windows
  deriving (Eq, Show)

-- | This host's operating system.
os :: OS
os =
  case System.os of
    "darwin" -> OSX
    "mingw32"  -> Windows
    "linux"  -> Linux
    _ -> error $ "Unknown host operating system: " ++ System.os

onlyOn :: [OS] -> (a -> a) -> (a -> a)
onlyOn which = onlyIf (os `elem` which)

notOn :: [OS] -> (a -> a) -> (a -> a)
notOn which = notIf (os `elem` which)

-- | File extension for executables.
executableExtension :: String
executableExtension =
  case os of
    Windows -> "exe"
    _       -> ""

-- | File extension for dynamic shared libraries.
sharedLibraryExtension :: String
sharedLibraryExtension =
  case os of
    Linux   -> "so"
    OSX     -> "dylib"
    Windows -> "dll"

-- | File extension for dynamic loadable libraries.
loadableLibraryExtension :: String
loadableLibraryExtension =
  case os of
    Linux   -> "so"
    OSX     -> "bundle"
    Windows -> "dll"

-- | Get host's default tool chain.
getDefaultToolChain :: IO (Target, ToolChain)
getDefaultToolChain =
  case os of
    Linux -> Linux.getDefaultToolChain
    OSX -> OSX.getDefaultToolChain
    Windows -> Windows.getDefaultToolChain
    _ -> error $ "No default toolchain for this operating system (" ++ show os ++ ")"

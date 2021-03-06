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

module Development.Shake.Language.C.Util (
    mapFlag
  , concatMapFlag
  , escapeSpaces
  , words'
) where

import Data.List

mapFlag :: String -> [String] -> [String]
mapFlag f = concatMap (\x -> [f, x])

concatMapFlag :: String -> [String] -> [String]
concatMapFlag f = map (f++)

-- | Escape spaces with '\\' character.
--
-- >>> escapeSpaces "string contains spaces"
-- "string\\ contains\\ spaces"
--
-- >>> escapeSpaces " leading and trailing spaces "
-- "\\ leading\\ and\\ trailing\\ spaces\\ "
--
-- >>> escapeSpaces "noSpaces"
-- "noSpaces"
--
escapeSpaces :: String -> String
escapeSpaces [] = []
escapeSpaces (' ':xs) = '\\' : ' ' : escapeSpaces xs
escapeSpaces ('\\':xs) = '\\' : '\\' : escapeSpaces xs
escapeSpaces (x:xs) = x : escapeSpaces xs

-- | Split a list of space separated strings.
--
-- Spaces can be escaped by '\\'.
--
-- >>> words' "word and word\\ with\\ spaces"
-- ["word","and","word with spaces"]
--
words' :: String -> [String]
words' = unescape . words
  where
    escape = "\\"
    escapeLength = length escape
    isEscaped = isSuffixOf escape
    dropEscape = (++" ") . reverse . drop escapeLength . reverse
    unescape [] = []
    unescape [x] = [if isEscaped x then dropEscape x else x]
    unescape (x1:x2:xs)
      | isEscaped x1 = unescape ((dropEscape x1 ++ x2):xs)
      | otherwise = [x1] ++ unescape (x2:xs)

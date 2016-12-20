{-# LANGUAGE CPP, OverloadedStrings #-}
module Main where
import Skylighting
import Data.Char (toLower)
import Control.Monad
import System.Exit
import System.Directory
import System.FilePath
import Data.Maybe (fromMaybe)
import Text.Printf
import System.IO
import Data.Monoid (mempty)
import Text.Printf
import Data.Algorithm.Diff
import Control.Applicative
import System.Environment (getArgs)
import Text.Blaze.Html
import Text.Blaze.Html.Renderer.String
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Test.HUnit

data TestResult = Pass | Fail | Error
                  deriving (Eq, Show)

main :: IO Counts
main = do
  inputs <- filter (\fp -> take 1 fp /= ".")
         <$> getDirectoryContents ("test" </> "cases")
  args <- getArgs
  let regen = "--regenerate" `elem` args
  runTestTT $ TestList $ map (mkTest regen) inputs

mkTest :: Bool -> FilePath -> Test
mkTest regen inpFile = TestLabel inpFile $ TestCase $ do
  let casesdir = "test" </> "cases"
  let expecteddir = "test" </> "expected"
  code <- readFile (casesdir </> inpFile)
  let lang = drop 1 $ takeExtension inpFile
  syntax <- case lookupSyntax lang defaultSyntaxMap of
                 Just s  -> return s
                 Nothing -> fail $
                    "Could not find syntax definition for " ++ lang
  actual <- case tokenize TokenizerConfig{
                               traceOutput = False
                             , syntaxMap = defaultSyntaxMap } syntax code of
                 Left e -> fail e
                 Right ls -> return $ renderHtml $
                                formatHtmlBlock defaultFormatOpts{
                                  titleAttributes = True } ls
  when regen $
    writeFile (expecteddir </> inpFile <.> "html") actual
  expectedString <- readFile (expecteddir </> inpFile <.> "html")
  when (expectedString /= actual) $ do
    putStrLn $ "--- " ++ (expecteddir </> inpFile <.> "html")
    putStrLn $ "+++ actual"
    printDiff expectedString actual
  assertEqual ("result of highlighting " ++ inpFile ++ " as expected")
              actual expectedString

formatHtml toks =
  renderHtml $ H.head (metadata >> css) >> H.body (toHtml fragment)
  where css = H.style ! A.type_ "text/css" $ toHtml $ styleToCss pygments
        fragment = formatHtmlBlock opts toks
        metadata = H.meta H.! A.charset "utf-8"
        opts = defaultFormatOpts{ titleAttributes = True }

vividize :: Diff String -> String
vividize (Both s _) = "  " ++ s
vividize (First s)  = "- " ++ s
vividize (Second s) = "+ " ++ s

printDiff :: String -> String -> IO ()
printDiff expected actual = do
  mapM_ putStrLn $ map vividize $ getDiff (lines expected) (lines actual)

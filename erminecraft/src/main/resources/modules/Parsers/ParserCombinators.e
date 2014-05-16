module Parsers.ParserCombinators where

import Bool
import Control.Functor
import Control.Monad
import Either
import Eq
import File
import Function hiding (|)
import List hiding or
import Native.Object using toString
import Maybe
import Parse
import Primitive
import String as String

data Parser a = Parser (List String -> ParseResult a) String

parserFunctor = monadFunctor parserMonad

parserMonad = Monad success bind' where
  bind' (Parser p name) f = Parser (args -> fold (p args) Failure (runParser . f)) name

runParser : Parser a -> List String -> ParseResult a
runParser (Parser f _) = f

nameOf : Parser a -> String
nameOf (Parser _ name) = name

rename : Parser a -> String -> Parser a
rename (Parser f _) name = Parser f name

success : a -> Parser a
success a = Parser (Success a) (toString a)

failure : String -> Parser a
failure msg = Parser (_ -> Failure msg) msg

data ParseResult a = Failure String | Success a (List String)

getOrElse : ParseResult a -> a -> a
getOrElse (Failure m)   a = a
getOrElse (Success a _) _ = a

fold : ParseResult a -> (String -> b) -> (a -> List String -> b) -> b
fold (Failure m)      failF _    = failF m
fold (Success a rest) _     sucF = sucF a rest

mapP = fmap parserFunctor
bindP = bind parserMonad
infixl 5 >>=
(>>=) = bindP

infixl 5 ^^
(^^) p f = mapP f p

infixl 3 ^^^
(^^^) p b = mapP (_ -> b) p

filterP : (a -> Bool) -> Parser a -> Parser a
filterP f p = filterWithP f (_ -> "invalid " ++_String (nameOf p)) p

filterWithP : (a -> Bool) -> (a -> String) -> Parser a -> Parser a
filterWithP f errorF p = bindP p (a -> (if (f a) (success a) (failure (errorF a))))

infixl 5 :&
data And a b = (:&) a b
--TODO: override def toString = s"($a ~ $b)"

andToList : And a (List a) -> List a
andToList (a :& as) = a :: as

infixl 5 &
(&) : Parser a -> Parser b -> Parser (And a b)
(&) p1 p2 = rename (p1 >>= (a -> mapP (b -> a :& b) p2)) ((nameOf p1) ++_String " " ++_String (nameOf p2))

infixl 5 |
(|) : Parser a -> Parser a -> Parser a
(|) p1 p2 = or p1 p2 ^^ f' where
  f' : Either a a -> a
  f' (Left  a) = a
  f' (Right a) = a

-- TODO: Ermine seems to have a naming issue. i wanted to name x' f',
-- TODO: but it conflicted with another f' below :(
or : Parser a -> Parser b -> Parser (Either a b)
or (Parser f1 name1) (Parser f2 name2) = Parser x' n' where
  x' args = case (f1 args) of
    (Success a rest) -> Success (Left a) rest
    (Failure m1)     -> case (f2 args) of
                          (Success b rest) -> Success (Right b) rest
                          (Failure m2)     -> Failure (m1 ++_String " or " ++_String m2)
  n' = name1 ++_String " or " ++_String name2

zeroOrMore : Parser a -> Parser (List a)
zeroOrMore p =  rename (oneOrMore p | success []) (nameOf p ++_String "*") where

oneOrMore  : Parser a -> Parser (List a)
oneOrMore p = rename ((p & (zeroOrMore p)) ^^ andToList) (nameOf p ++_String "+")

opt : Parser a -> Parser (Maybe a)
opt (Parser f n) = Parser f' n' where
  f' args = fold (f args) (_ -> Success Nothing args) (t rest -> Success (Just t) rest)
  n' = "optional(" ++_String n ++_String ")"

infixl 5 ~>
(~>) : Parser a -> Parser b -> Parser b
(~>) p1 p2 = bindP p1 (a -> p2)

infixl 5 <~
(<~) : Parser a -> Parser b -> Parser a
(<~) p1 p2 = bindP p1 (a -> p2 ^^^ a)

repSep : Parser a -> Parser b -> Parser (List a)
repSep p1 p2 = p1 & oneOrMore (p2 ~> p1) ^^ andToList

eof : Parser ()
eof = Parser empty' "EOF" where
  empty' : List String -> ParseResult ()
  empty' [] = Success () []
  empty' ss = Failure $ concat_String ("unprocessed input" :: ss)

noArguments = rename eof ""
nothing     = rename eof ""
empty       = rename eof ""

anyStringAs : String -> Parser String
anyStringAs name = Parser f' name where
  f' : List String -> ParseResult String
  f' [] = Failure $ concat_String ["expected ", name, " but got nothing"]
  f' (x::xs) = Success x xs

anyString: Parser String
anyString = anyStringAs "string"

slurp: Parser String
slurp = rename (zeroOrMore anyString ^^ unwords_String) "slurp"

remainingArgs: Parser (List String)
remainingArgs = Parser (flip Success []) "remainingArgs"

-- TODO: need a show instance for a
maybeP : String -> (String -> Maybe a) -> Parser a
maybeP name f = bindP (anyStringAs name) (s -> maybe (failure $ concat_String ["invalid", name, toString s]) (success) (f s))

int    : Parser Int
int    = maybeP "int" (parseInt 10)
byte   : Parser Byte
byte   = maybeP "byte" (parseByte 10)
long   : Parser Long
long   = maybeP "long" (parseLong 10)
short  : Parser Short
short  = maybeP "short" (parseShort 10)
double : Parser Double
double = maybeP "double" parseDouble
float  : Parser Float
float  = maybeP "float" parseFloat

evenInt = filterP even (rename int "even-int")
oddInt  = filterP odd  (rename int "odd-int")
even n = n % 2 == 0
odd = not . even

bool        = maybeP "boolean" parseBool
boolOrTrue  = bool | success True
boolOrFalse = bool | success False
string s = filterWithP ((==) s) (_ -> concat_String ["expected: ", s]) (anyStringAs s)

binary: Parser String
binary = (oneOrMore (string "0" | string "1")) ^^ concat_String

-- file parsers
-- TODO: fix so that filenameP only accepts valid file names.
filename = anyStringAs "file-name"
file = filename ^^ file#
existingFile = rename (filterP fileExists file) "existing-file"

-- TODO: add to ermine lib.
foreign
  method "exists" fileExists : File -> Bool

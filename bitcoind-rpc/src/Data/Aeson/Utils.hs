{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE TypeApplications #-}

{- |
 Module: Data.Aeson.Utils

 Helper functions for JSON (de)serialization
-}
module Data.Aeson.Utils (
    partialObject,
    (.=?),
    utcTime,
    toSatoshis,
    satsPerBTC,
    satsToBTCText,
    decodeFromHex,
    rangeToJSON,
    HexEncoded (..),
    Base64Encoded (..),
) where

import Control.Monad ((<=<), (>=>))
import Data.Aeson (
    FromJSON (..),
    ToJSON (..),
    Value,
    object,
    withText,
    (.=),
 )
import Data.Aeson.Types (Pair)
import Data.Bifunctor (first)
import Data.ByteString.Base64 (decodeBase64, encodeBase64)
import Data.Maybe (catMaybes)
import Data.Scientific (Scientific)
import Data.Serialize (Serialize, decode)
import qualified Data.Serialize as S
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Encoding (encodeUtf8)
import Data.Time (UTCTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Data.Word (Word64)
import Haskoin.Util (decodeHex, encodeHex)

partialObject :: [Maybe Pair] -> Value
partialObject = object . catMaybes

(.=?) :: ToJSON a => Text -> Maybe a -> Maybe (Text, Value)
k .=? mv = (k .=) <$> mv

-- | Helper function for decoding POSIX timestamps
utcTime :: Word64 -> UTCTime
utcTime = posixSecondsToUTCTime . fromIntegral

-- | Convert BTC to Satoshis
toSatoshis :: Scientific -> Word64
toSatoshis = floor . (* satsPerBTC)

satsPerBTC :: Num a => a
satsPerBTC = 1_0000_0000

-- | Convert sats to BTC
satsToBTCText :: Word64 -> Text
satsToBTCText = Text.pack . show . (/ 1_0000_0000) . fromIntegral @_ @Scientific

rangeToJSON :: (Int, Maybe Int) -> Value
rangeToJSON (n, Just m) = toJSON [n, m]
rangeToJSON (n, _) = toJSON n

-- | Read a serializable from a hex string
decodeFromHex :: Serialize a => Text -> Either String a
decodeFromHex = maybe (Left "Invalid hex") Right . decodeHex >=> decode

newtype HexEncoded a = HexEncoded {unHexEncoded :: a} deriving (Eq, Show)

instance Serialize a => FromJSON (HexEncoded a) where
    parseJSON = withText "HexEncoded" $ either fail (return . HexEncoded) . decodeFromHex

instance Serialize a => ToJSON (HexEncoded a) where
    toJSON = toJSON . encodeHex . S.encode . unHexEncoded

newtype Base64Encoded a = Base64Encoded {unBase64Encoded :: a} deriving (Eq, Show)

instance Serialize a => FromJSON (Base64Encoded a) where
    parseJSON =
        withText "Base64Encoded" $
            either fail (pure . Base64Encoded)
                . (S.decode <=< first Text.unpack . decodeBase64)
                . encodeUtf8

instance Serialize a => ToJSON (Base64Encoded a) where
    toJSON = toJSON . encodeBase64 . S.encode . unBase64Encoded

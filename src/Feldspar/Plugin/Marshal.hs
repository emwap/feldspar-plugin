{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Feldspar.Plugin.Marshal where

import Foreign.Ptr (Ptr)
import Foreign.Marshal (new, newArray, peekArray)
import Foreign.Marshal.Unsafe (unsafeLocalState)
import Foreign.Storable (Storable(..))
import Foreign.Storable.Tuple ()
import Data.Int
import Data.Word
import Data.Complex
import Control.Applicative
import qualified Foreign.Storable.Record as Store

import Feldspar.Core.Types (IntN(..), WordN(..))

import Debug.Trace

data SA a = SA { buf   :: Ptr a
               , elems :: Int32
               , esize :: Int32
               , bytes :: Word32
               }
  deriving (Eq, Show)

storeSA :: Storable a => Store.Dictionary (SA a)
storeSA = Store.run $ SA
    <$> Store.element buf
    <*> Store.element elems
    <*> Store.element esize
    <*> Store.element bytes

instance Storable a => Storable (SA a)
  where
    sizeOf    = Store.sizeOf    storeSA
    alignment = Store.alignment storeSA
    peek      = Store.peek      storeSA
    poke      = Store.poke      storeSA

deriving instance Storable IntN
deriving instance Storable WordN

storeComplex :: (RealFloat a, Storable a)
             => Store.Dictionary (Complex a)
storeComplex = Store.run $ (:+)
    <$> Store.element realPart
    <*> Store.element imagPart

instance (RealFloat a, Storable a) => Storable (Complex a)
  where
    sizeOf    = Store.sizeOf    storeComplex
    alignment = Store.alignment storeComplex
    peek      = Store.peek      storeComplex
    poke      = Store.poke      storeComplex



class Reference a
  where
    type Ref a :: *

    ref         ::                a -> Ref a
    default ref :: (a ~ Ref a) => a -> Ref a
    ref = id

    deref :: Ref a -> IO a
    default deref :: (a ~ Ref a) => Ref a -> IO a
    deref = return

instance Reference Bool        where type Ref Bool        = Bool
instance Reference Int8        where type Ref Int8        = Int8
instance Reference Int16       where type Ref Int16       = Int16
instance Reference Int32       where type Ref Int32       = Int32
instance Reference Int64       where type Ref Int64       = Int64
instance Reference IntN        where type Ref IntN        = IntN
instance Reference Word8       where type Ref Word8       = Word8
instance Reference Word16      where type Ref Word16      = Word16
instance Reference Word32      where type Ref Word32      = Word32
instance Reference Word64      where type Ref Word64      = Word64
instance Reference WordN       where type Ref WordN       = WordN
instance Reference Float       where type Ref Float       = Float
instance Reference Double      where type Ref Double      = Double
instance Reference (Complex a) where type Ref (Complex a) = Complex a

instance (Storable a) => Reference (SA a)
  where
    type Ref (SA a) = Ptr (SA a)
    ref a = unsafeLocalState $ new a
    deref = peek

instance Storable (a,b) => Reference (a,b)
  where
    type Ref (a,b) = Ptr (a,b)
    ref a = unsafeLocalState $ new a
    deref = peek

instance Storable (a,b,c) => Reference (a,b,c)
  where
    type Ref (a,b,c) = Ptr (a,b,c)
    ref a = unsafeLocalState $ new a
    deref = peek

instance Storable (a, b, c, d) => Reference (a,b,c,d)
  where
    type Ref (a,b,c,d) = Ptr (a,b,c,d)
    ref a = unsafeLocalState $ new a
    deref = peek

instance Storable (a, b, c, d, e) => Reference (a,b,c,d,e)
  where
    type Ref (a,b,c,d,e) = Ptr (a,b,c,d,e)
    ref a = unsafeLocalState $ new a
    deref = peek

instance Storable (a, b, c, d, e, f) => Reference (a,b,c,d,e,f)
  where
    type Ref (a,b,c,d,e,f) = Ptr (a,b,c,d,e,f)
    ref a = unsafeLocalState $ new a
    deref = peek

instance Storable (a, b, c, d, e, f, g) => Reference (a,b,c,d,e,f,g)
  where
    type Ref (a,b,c,d,e,f,g) = Ptr (a,b,c,d,e,f,g)
    ref a = unsafeLocalState $ new a
    deref = peek


class Marshal a
  where
    type Rep a :: *

    to         ::                a -> Rep a
    default to :: (a ~ Rep a) => a -> Rep a
    to = id

    from :: Rep a -> IO a
    default from :: (a ~ Rep a) => Rep a -> IO a
    from = return

instance Marshal Bool        where type Rep Bool        = Bool
instance Marshal Int8        where type Rep Int8        = Int8
instance Marshal Int16       where type Rep Int16       = Int16
instance Marshal Int32       where type Rep Int32       = Int32
instance Marshal Int64       where type Rep Int64       = Int64
instance Marshal IntN        where type Rep IntN        = IntN
instance Marshal Word8       where type Rep Word8       = Word8
instance Marshal Word16      where type Rep Word16      = Word16
instance Marshal Word32      where type Rep Word32      = Word32
instance Marshal Word64      where type Rep Word64      = Word64
instance Marshal WordN       where type Rep WordN       = WordN
instance Marshal Float       where type Rep Float       = Float
instance Marshal Double      where type Rep Double      = Double
instance Marshal (Complex a) where type Rep (Complex a) = Complex a


instance (Storable (Rep a), Marshal a) => Marshal [a]
  where
    type Rep [a] = SA (Rep a)
    to xs = unsafeLocalState $ do
        let len  = fromIntegral $ length xs
        let size = fromIntegral $ sizeOf (undefined :: Rep a)
        let ys   = map to xs
        buffer <- newArray ys
        return $ SA buffer len size (fromIntegral (len * size))
    from SA{..} = do
        mapM from =<< peekArray (fromIntegral elems) buf

instance (Marshal a, Marshal b) => Marshal (a,b)
  where
    type Rep (a,b) = (Rep a,Rep b)
    to (a,b) = (to a, to b)
    from (a,b) = (,) <$> from a <*> from b

instance ( Marshal a
         , Marshal b
         , Marshal c
         ) => Marshal (a,b,c)
  where
    type Rep (a,b,c) = (Rep a,Rep b,Rep c)
    to (a,b,c) = (to a, to b, to c)
    from (a,b,c) = (,,) <$> from a <*> from b <*> from c

instance ( Marshal a
         , Marshal b
         , Marshal c
         , Marshal d
         ) => Marshal (a,b,c,d)
  where
    type Rep (a,b,c,d) = (Rep a,Rep b,Rep c,Rep d)
    to (a,b,c,d) = (to a, to b, to c, to d)
    from (a,b,c,d) =
      (,,,) <$> from a <*> from b <*> from c <*> from d

instance ( Marshal a
         , Marshal b
         , Marshal c
         , Marshal d
         , Marshal e
         ) => Marshal (a,b,c,d,e)
  where
    type Rep (a,b,c,d,e) = (Rep a,Rep b,Rep c,Rep d,Rep e)
    to (a,b,c,d,e) = (to a, to b, to c, to d, to e)
    from (a,b,c,d,e) =
      (,,,,) <$> from a <*> from b <*> from c <*> from d <*> from e

instance ( Marshal a
         , Marshal b
         , Marshal c
         , Marshal d
         , Marshal e
         , Marshal f
         ) => Marshal (a,b,c,d,e,f)
  where
    type Rep (a,b,c,d,e,f) = (Rep a,Rep b,Rep c,Rep d,Rep e,Rep f)
    to (a,b,c,d,e,f) = (to a, to b, to c, to d, to e, to f)
    from (a,b,c,d,e,f) =
      (,,,,,) <$> from a <*> from b <*> from c <*> from d <*> from e <*> from f

instance ( Marshal a
         , Marshal b
         , Marshal c
         , Marshal d
         , Marshal e
         , Marshal f
         , Marshal g
         ) => Marshal (a,b,c,d,e,f,g)
  where
    type Rep (a,b,c,d,e,f,g) = (Rep a,Rep b,Rep c,Rep d,Rep e,Rep f,Rep g)
    to (a,b,c,d,e,f,g) = (to a, to b, to c, to d, to e, to f, to g)
    from (a,b,c,d,e,f,g) =
      (,,,,,,) <$> from a <*> from b <*> from c <*> from d <*> from e <*> from f <*> from g


{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Marshalling of data to and from a loaded Feldspar function
module Foreign.Marshal.Class
  ( pack, unpack
  , Marshal(..)
  , Reference(..)
  )
  where

import Foreign.Ptr (Ptr)
import Foreign.Marshal (new)
import Foreign.Storable (Storable(..))
import Data.Int
import Data.Word
import Control.Applicative

-- | Pack a value into its runtime representation
--
-- > pack a = to a >>= ref
--
pack :: (Reference (Rep a), Marshal a) => a -> IO (Ref (Rep a))
pack a = to a >>= ref

-- | Unpack a value from its runtime representation
--
-- > unpack a = deref a >>= from
--
unpack :: (Reference (Rep a), Marshal a) => Ref (Rep a) -> IO a
unpack a = deref a >>= from

-- | Optionally make a refrence of a value
class Reference a
  where
    -- | The type of a referenced value
    type Ref a :: *

    -- | Convert to a referenced value
    ref         ::                a -> IO (Ref a)
    default ref :: (a ~ Ref a) => a -> IO (Ref a)
    {-# INLINE ref #-}
    ref a = return a

    -- | Convert from a referenced value
    -- In the IO monad to allow @peek@ing through the reference.
    deref         ::                Ref a -> IO a
    default deref :: (a ~ Ref a) => Ref a -> IO a
    {-# INLINE deref #-}
    deref a = return a

instance Reference Bool        where type Ref Bool        = Bool
instance Reference Int8        where type Ref Int8        = Int8
instance Reference Int16       where type Ref Int16       = Int16
instance Reference Int32       where type Ref Int32       = Int32
instance Reference Int64       where type Ref Int64       = Int64
instance Reference Word8       where type Ref Word8       = Word8
instance Reference Word16      where type Ref Word16      = Word16
instance Reference Word32      where type Ref Word32      = Word32
instance Reference Word64      where type Ref Word64      = Word64
instance Reference Float       where type Ref Float       = Float
instance Reference Double      where type Ref Double      = Double

instance (Storable (a,b)) => Reference (a,b)
  where
    type Ref (a,b) = Ptr (a,b)
    ref   = new
    deref = peek

instance (Storable (a,b,c)) => Reference (a,b,c)
  where
    type Ref (a,b,c) = Ptr (a,b,c)
    ref   = new
    deref = peek

instance (Storable (a,b,c,d)) => Reference (a,b,c,d)
  where
    type Ref (a,b,c,d) = Ptr (a,b,c,d)
    ref   = new
    deref = peek

instance (Storable (a,b,c,d,e)) => Reference (a,b,c,d,e)
  where
    type Ref (a,b,c,d,e) = Ptr (a,b,c,d,e)
    ref   = new
    deref = peek

instance (Storable (a,b,c,d,e,f)) => Reference (a,b,c,d,e,f)
  where
    type Ref (a,b,c,d,e,f) = Ptr (a,b,c,d,e,f)
    ref   = new
    deref = peek

instance (Storable (a,b,c,d,e,f,g)) => Reference (a,b,c,d,e,f,g)
  where
    type Ref (a,b,c,d,e,f,g) = Ptr (a,b,c,d,e,f,g)
    ref   = new
    deref = peek


-- | Convert between Haskell and representation types
class Marshal a
  where
    type Rep a :: *

    to         ::                a -> IO (Rep a)
    default to :: (a ~ Rep a) => a -> IO (Rep a)
    {-# INLINE to #-}
    to a = return a

    from         ::                Rep a -> IO a
    default from :: (a ~ Rep a) => Rep a -> IO a
    {-# INLINE from #-}
    from a = return a

instance Marshal Bool        where type Rep Bool        = Bool
instance Marshal Int8        where type Rep Int8        = Int8
instance Marshal Int16       where type Rep Int16       = Int16
instance Marshal Int32       where type Rep Int32       = Int32
instance Marshal Int64       where type Rep Int64       = Int64
instance Marshal Word8       where type Rep Word8       = Word8
instance Marshal Word16      where type Rep Word16      = Word16
instance Marshal Word32      where type Rep Word32      = Word32
instance Marshal Word64      where type Rep Word64      = Word64
instance Marshal Float       where type Rep Float       = Float
instance Marshal Double      where type Rep Double      = Double


instance (Marshal a, Marshal b) => Marshal (a,b)
  where
    type Rep (a,b) = (Rep a,Rep b)
    to (a,b)   = (,) <$> to a <*> to b
    from (a,b) = (,) <$> from a <*> from b

instance ( Marshal a
         , Marshal b
         , Marshal c
         ) => Marshal (a,b,c)
  where
    type Rep (a,b,c) = (Rep a,Rep b,Rep c)
    to (a,b,c)   = (,,) <$> to a <*> to b <*> to c
    from (a,b,c) = (,,) <$> from a <*> from b <*> from c

instance ( Marshal a
         , Marshal b
         , Marshal c
         , Marshal d
         ) => Marshal (a,b,c,d)
  where
    type Rep (a,b,c,d) = (Rep a,Rep b,Rep c,Rep d)
    to (a,b,c,d) =
      (,,,) <$> to a <*> to b <*> to c <*> to d
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
    to (a,b,c,d,e) =
      (,,,,) <$> to a <*> to b <*> to c <*> to d <*> to e
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
    to (a,b,c,d,e,f) =
      (,,,,,) <$> to a <*> to b <*> to c <*> to d <*> to e <*> to f
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
    to (a,b,c,d,e,f,g) =
      (,,,,,,) <$> to a <*> to b <*> to c <*> to d <*> to e <*> to f <*> to g
    from (a,b,c,d,e,f,g) =
      (,,,,,,) <$> from a <*> from b <*> from c <*> from d <*> from e <*> from f <*> from g


{-# LANGUAGE ForeignFunctionInterface #-}
{-# OPTIONS_GHC -w #-}
#if __GLASGOW_HASKELL__ >= 701
{-# LANGUAGE Trustworthy #-}
#endif
-- The above warning supression flag is a temporary kludge.
-- While working on this module you are encouraged to remove it and fix
-- any warnings in the module. See
--     http://hackage.haskell.org/trac/ghc/wiki/WorkingConventions#Warnings
-- for details
-----------------------------------------------------------------------------
-- |
-- Module      :  System.Posix.Resource
-- Copyright   :  (c) The University of Glasgow 2003
-- License     :  BSD-style (see the file libraries/base/LICENSE)
-- 
-- Maintainer  :  libraries@haskell.org
-- Stability   :  provisional
-- Portability :  non-portable (requires POSIX)
--
-- POSIX resource support
--
-----------------------------------------------------------------------------

module System.Posix.Resource (
    -- * Resource Limits
    ResourceLimit(..), ResourceLimits(..), Resource(..),
    getResourceLimit,
    setResourceLimit,
  ) where

#include "HsUnix.h"

import System.Posix.Types
import Foreign
import Foreign.C

-- -----------------------------------------------------------------------------
-- Resource limits

data Resource
  = ResourceCoreFileSize
  | ResourceCPUTime
  | ResourceDataSize
  | ResourceFileSize
  | ResourceOpenFiles
  | ResourceStackSize
#ifdef RLIMIT_AS
  | ResourceTotalMemory
#endif
  deriving Eq

data ResourceLimits
  = ResourceLimits { softLimit, hardLimit :: ResourceLimit }
  deriving Eq

data ResourceLimit
  = ResourceLimitInfinity
  | ResourceLimitUnknown
  | ResourceLimit Integer
  deriving Eq

type RLimit = ()

foreign import ccall unsafe "HsUnix.h __hscore_getrlimit"
  c_getrlimit :: CInt -> Ptr RLimit -> IO CInt

foreign import ccall unsafe "HsUnix.h __hscore_setrlimit"
  c_setrlimit :: CInt -> Ptr RLimit -> IO CInt

getResourceLimit :: Resource -> IO ResourceLimits
getResourceLimit res = do
  allocaBytes (#const sizeof(struct rlimit)) $ \p_rlimit -> do
    throwErrnoIfMinus1 "getResourceLimit" $
      c_getrlimit (packResource res) p_rlimit
    soft <- (#peek struct rlimit, rlim_cur) p_rlimit
    hard <- (#peek struct rlimit, rlim_max) p_rlimit
    return (ResourceLimits { 
		softLimit = unpackRLimit soft,
		hardLimit = unpackRLimit hard
	   })

setResourceLimit :: Resource -> ResourceLimits -> IO ()
setResourceLimit res ResourceLimits{softLimit=soft,hardLimit=hard} = do
  allocaBytes (#const sizeof(struct rlimit)) $ \p_rlimit -> do
    (#poke struct rlimit, rlim_cur) p_rlimit (packRLimit soft True)
    (#poke struct rlimit, rlim_max) p_rlimit (packRLimit hard False)
    throwErrnoIfMinus1 "setResourceLimit" $
	c_setrlimit (packResource res) p_rlimit
    return ()

packResource :: Resource -> CInt
packResource ResourceCoreFileSize  = (#const RLIMIT_CORE)
packResource ResourceCPUTime       = (#const RLIMIT_CPU)
packResource ResourceDataSize      = (#const RLIMIT_DATA)
packResource ResourceFileSize      = (#const RLIMIT_FSIZE)
packResource ResourceOpenFiles     = (#const RLIMIT_NOFILE)
packResource ResourceStackSize     = (#const RLIMIT_STACK)
#ifdef RLIMIT_AS
packResource ResourceTotalMemory   = (#const RLIMIT_AS)
#endif

unpackRLimit :: CRLim -> ResourceLimit
unpackRLimit (#const RLIM_INFINITY)  = ResourceLimitInfinity
#ifdef RLIM_SAVED_MAX
unpackRLimit (#const RLIM_SAVED_MAX) = ResourceLimitUnknown
unpackRLimit (#const RLIM_SAVED_CUR) = ResourceLimitUnknown
#endif
unpackRLimit other = ResourceLimit (fromIntegral other)

packRLimit :: ResourceLimit -> Bool -> CRLim
packRLimit ResourceLimitInfinity _     = (#const RLIM_INFINITY)
#ifdef RLIM_SAVED_MAX
packRLimit ResourceLimitUnknown  True  = (#const RLIM_SAVED_CUR)
packRLimit ResourceLimitUnknown  False = (#const RLIM_SAVED_MAX)
#endif
packRLimit (ResourceLimit other) _     = fromIntegral other


-- -----------------------------------------------------------------------------
-- Test code

{-
import System.Posix
import Control.Monad

main = do
 zipWithM_ (\r n -> setResourceLimit r ResourceLimits{
					hardLimit = ResourceLimit n,
					softLimit = ResourceLimit n })
	allResources [1..]	
 showAll
 mapM_ (\r -> setResourceLimit r ResourceLimits{
					hardLimit = ResourceLimit 1,
					softLimit = ResourceLimitInfinity })
	allResources
   -- should fail


showAll = 
  mapM_ (\r -> getResourceLimit r >>= (putStrLn . showRLims)) allResources

allResources =
    [ResourceCoreFileSize, ResourceCPUTime, ResourceDataSize,
	ResourceFileSize, ResourceOpenFiles, ResourceStackSize
#ifdef RLIMIT_AS
	, ResourceTotalMemory 
#endif
	]

showRLims ResourceLimits{hardLimit=h,softLimit=s}
  = "hard: " ++ showRLim h ++ ", soft: " ++ showRLim s
 
showRLim ResourceLimitInfinity = "infinity"
showRLim ResourceLimitUnknown  = "unknown"
showRLim (ResourceLimit other)  = show other
-}

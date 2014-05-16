module Minecraft.Native where

import Either
import IO.Unsafe
import Native.Function

-- all the foreign imports for Bukkit code
foreign
  data "org.bukkit.entity.EntityType" EntityType
  function "org.bukkit.entity.EntityType" "fromName" entityFromName : String -> EntityType
  function "org.bukkit.entity.EntityType" "valueOf"  entityValueOf  : String -> EntityType

  data "org.bukkit.entity.Player" Player
  method "sendMessage" sendMessage : Player -> String -> IO ()
  method "getWorld"    getWorldFromPlayer : Player -> IO World
  method "getLocation" getLocationFromPlayer : Player -> IO Location
  method "getServer"   getServerFromPlayer : Player -> Server
  method "teleport"    teleport : Player -> Location -> IO Bool

  data "org.bukkit.plugin.Plugin" Plugin
  method "getServer" getServerFromPlugin : Plugin -> Server

  data "org.bukkit.plugin.PluginManager" PluginManager
  method "getPlugin" getPlugin# : PluginManager -> String -> FFI Plugin
  method "registerEvents" registerEvents : PluginManager -> Listener -> Plugin -> IO ()

  data "org.bukkit.Server" Server
  method "getPlayer" getPlayer : Server -> String -> FFI Player
  method "getPluginManager" getPluginManager : Server -> PluginManager

  data "org.bukkit.World" World
  method "strikeLightning" strikeLightning : World -> Location -> IO LightningStrike
  method "getHighestBlockAt" getHighestBlockAt : World -> Int -> Int -> IO Block

  data "org.bukkit.Location" Location
  constructor location# : World -> Double -> Double -> Double -> Location
  method "getBlock" getBlock : Location -> Block
  method "getWorld" getWorldFromLocation : Location -> World

  data "org.bukkit.entity.LightningStrike" LightningStrike
  data "org.bukkit.event.Listener" Listener
  data "org.bukkit.event.block.BlockDamageEvent" BlockDamageEvent

  data "org.bukkit.Material" Material
  value "org.bukkit.Material" "GOLD_BLOCK" gold : Material
  value "org.bukkit.Material" "DIAMOND_BLOCK" diamond : Material
  function "org.bukkit.Material" "getMaterial" getMaterialById# : Int -> FFI Material
  function "org.bukkit.Material" "getMaterial" getMaterialByName# : String -> FFI Material

  data "org.bukkit.block.Block" Block
  method "setType" setType : Block -> Material -> IO ()
  method "getLocation" getLocationFromBlock : Block -> Location
  method "getWorld" getWorldFromBlock : Block -> World
  method "getX" blockX : Block -> Int
  method "getY" blockY : Block -> Int
  method "getZ" blockZ : Block -> Int

  function "com.joshcough.minecraft.ListenersObject" "OnBlockDamage" onBlockDamage# : Function2 Block BlockDamageEvent (IO ()) -> Listener

  data "org.bukkit.GameMode" GameMode
  value "org.bukkit.GameMode" "CREATIVE" creative : GameMode
  value "org.bukkit.GameMode" "SURVIVAL" survival : GameMode

  data "org.bukkit.command.Command" BukkitCommand


--TODO move to String
foreign
  method "toUpperCase" toUpperCase : String -> String

--TODO: move to IO.Unsafe
ffiToMaybe : FFI a -> Maybe a
ffiToMaybe f = case unsafeFFI f of
  Left e  -> Nothing
  Right a -> Just a

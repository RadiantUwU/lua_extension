# lua_extension

#### Contents
 * [About](#about)
 * [Dependencies](#dependencies)
 * [Downloading](#downloading)
 * [Documentation](#docs)
    * [LuaRuntimeController](#luaruntimecontroller)
    * [Other Classes](#other_classes)

## Before downloading

This software is provided "as is" and if you do find any security vulnerabilities please disclose them to me **privately** over at [my guilded](https://www.guilded.gg/u/radiantuwu).

## About

This library extends the [base library](https://github.com/WeaselGames/godot_luaAPI) to implement two layers, a `core` layer and a `user` layer.

As the name explains, `core` has full privileges over everything, and `user` is limited.

This allows you to load UGC into `user`, for example mods, scripts, anything.

By default, these built-in libraries have been modified or completely removed to make sure the `user` layer under no circumstances can do anything dangerous:

 * `debug` (only getinfo and traceback is available.)
 * ~~`io`~~ (completely removed)
 * `os` (time-related functions are the only ones left available.)
 * ~~`package`~~ (completely removed)

## Features

 * Yielding of the state or completely terminating it externally (may work from another thread as long as the hook has not been changed through debug.sethook)
    * **Note:** Run `LuaRuntimeController.restore()` after a yield/terminate so it doesn't immedieately yield/terminate again.
 * `getfenv` and `setfenv` implementations in Lua 5.4, as well as a `protect_fn` to protect function enviroments from either being read or written to. You can also use `is_fn_protected` to check if a function is protected.
    * **Note:** The core layer functions `_getfenv` and `_setfenv` completely bypass `protect_fn`.
 * New table functions for extra security and QoL:
    * `table.clone(t: table) -> copy of t`
    * `table.base(...) -> table` Supplied with `n` tables, copies keys from the 1st, then 2nd, all the way to n, essentially overlapping them, the further from the 1st argument, the more keys the table would be able to overlap.
    * `table.baseinto(tbl: table,...) -> tbl` Same as `table.base`, but you can specify a table in where to perform the overlapping operations.
    * `table.freeze(tbl: table) -> tbl` Allows to completely freeze tables. This will not allow modifying its metatable or its contents, even with `rawset`.
        * **Note:** You may disallow freezing of a table by setting a key in its metatable `__isfrozen` to `true``
    * `table.isfrozen(tbl: table) -> bool` Check if a table is frozen by indexing __isfrozen in its metatable.
    * `table.clear(tbl: table) -> tbl` A macro iterating through all keys and setting them to nil. Will not work if the metatable disallows it or the table is frozen.
    * `table.overwrite(tbl_to_be_overwritten: table, tbl_to_overwrite_from: table) -> tbl_to_be_overwritten` Raises an error if `tbl_to_be_overwritten` has a protected metatable. Clears 1st table, does a shallow copy of 2nd table to 1st, sets its metatable to the 2nd table's metatable.
    * `table.reference(t1: table, t2: table) -> t1` Raises an error if `t1` has a protected metatable. Clears `t1`, makes any iterating, indexing, setting or even getting the length of it. Sadly, there is no `__hash` so it still will be its own object.
* A new function `coroutine.terminate() -> noreturn` to terminate the current running coroutine. If it cannot yield, will throw an error.
* Completely configurable user environments, an easy way to create user environments and switch between them.
   * `core_env.add_to_user_env(name: string, var: any, immutable: boolean = true) -> void` Writes to the user environment. Sets it to be modifiable or not by the user_environment (will only be on the one clone).
* `loadstring` implementation in Lua 5.4, as `user_env.load` is now disabled. Allowing to load binary data is a security vulnerability.
* `user_env.collectgarbage` can now only show how much memory is currently in use.
* `core_env.rawpairs` implementation to skip over metamethods.
* Full access to all godot classes and instances in the core environment.
* `print`, `warn` and `log_error` have signals for when they are emitted. They may also be overloaded to also print the traceback.
## Dependencies

This library depends on https://github.com/WeaselGames/godot_luaAPI

## Downloading

Simply go to the tab on the right with releases, you should find already packaged ones.

## Docs

### LuaRuntimeController

This is the core of this library.

### Other classes

#### LuaCrypto

Most of the times when it asks for a PackedByteArray it has instead been replaced with a string.

`LuaCrypto()` (constructor)
> Creates a new LuaCrypto object.

`constant_time_compare(s1: string, s2: string) -> boolean`
> Checks both strings in a constant time to not be susceptible to time attacks.

`generate_random_bytes(length: integer) -> string`
> Generates `length` bytes and returns a string containing them.

`encrypt(key: LuaCryptoKey, text: string) -> string`
> Encrypts using an RSA public key. The text should be at most the same amount of bytes as the key.

`decrypt(key: LuaCryptoKey, encrypted: string) -> string`
> Decrypts using an RSA private key.

`generate_rsa_key(bits: integer) -> LuaCryptoKey`
> Creates an RSA key of `bits` length. 8 bits is one byte.

### LuaCryptoKey
(empty, no methods on the class itself.)

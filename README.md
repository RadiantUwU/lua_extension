# lua_extension

#### Contents
 * [Dependencies](#dependencies)

## Dependencies

This library depends on https://github.com/WeaselGames/godot_luaAPI

## Before downloading

This software is provided "as is" and if you do find any security vulnerabilities please disclose them to me **privately** over at [my guilded](https://www.guilded.gg/u/radiantuwu).

## Downloading


## Other classes

### LuaCrypto

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

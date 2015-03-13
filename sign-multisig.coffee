Script = require 'btc-script'
BigInteger = require 'bigi'
ecdsa = require 'ecdsa'
curve = require('ecurve').getCurveByName('secp256k1')
{ map: { OP_0 } } = require 'btc-opcode'
SIGHASH_ALL = 1

# Sign `tx` with `key`, where all inputs are to be redeemed with `redeem_script`,
# keeping previous signatures in place and in correct order
module.exports = (privkey, tx, redeem_script, hash_type=SIGHASH_ALL) ->
  pubkey = curve.G.multiply(BigInteger.fromBuffer privkey).getEncoded(true)

  pubkeys = redeem_script.extractPubkeys().map (pubkey) -> new Buffer pubkey
  hpubkeys = pubkeys.map (pubkey) -> pubkey.toString 'hex'

  throw new Error 'Invalid key' unless pubkey.toString('hex') in hpubkeys

  tx.ins.forEach (inv, i) ->
    sighash = new Buffer tx.hashTransactionForSignature redeem_script, i, hash_type

    sigs = get_script_sigs pubkeys, inv.script, sighash, hash_type
    sigs[pubkey.toString 'hex'] = sign sighash, privkey

    in_script = new Script
    in_script.writeOp OP_0
    for pubkey_hex in hpubkeys when sig = sigs[pubkey_hex]
      in_script.writeBytes [ sig..., hash_type ]
    in_script.writeBytes redeem_script.buffer

    inv.script = in_script

  tx

# Get the previous signatures, on an object map with the signing public key as the hash key
get_script_sigs = (pubkeys, script, sighash, hash_type) ->
  return {} unless script.chunks.length

  unless script.chunks[0] is OP_0 and script.chunks.length >= 2
    throw new Error 'Invalid script'

  pubkeys = pubkeys[..] # clone
  sigs = {}
  for sig in script.chunks[1...-1]
    unless sig[sig.length-1] is hash_type
      throw new Error 'Invalid hash type in signature'
    sig = new Buffer sig[...-1]
    unless signer = get_signer pubkeys, sig, sighash
      throw new Error 'Invalid signature'
    sigs[signer.toString 'hex'] = sig
    # Remove all public keys up to the current signing key.
    # Signatures must be in the same order as pubkeys, meaning that pubkeys
    # before the current one cannot be used for the next sigs.
    pubkeys.splice 0, pubkeys.indexOf(signer)+1
  sigs

# Get the signing public key that created `sig` over `sighash`
get_signer = (pubkeys, sig, sighash) ->
  for pubkey in pubkeys when verify sighash, sig, pubkey
    return pubkey
  return

sign = (data, privkey) -> new Buffer ecdsa.serializeSig ecdsa.sign data, privkey
verify = (data, sig, pubkey) -> ecdsa.verify data, (ecdsa.parseSig sig), pubkey

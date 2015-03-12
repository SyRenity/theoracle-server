iferr = require 'iferr'
BigInteger = require 'bigi'
HDKey = require 'hdkey'
blocktrail = require 'blocktrail-sdk'
coinstring = require 'coinstring'
coininfo = require 'coininfo'
{ sha256, sha256ripe160 } = require 'crypto-hashing'
{ createMultiSigOutputScript } = require 'btc-script'
curve = require('ecurve').getCurveByName('secp256k1')

api_key = process.env.BLOCKTRAIL_API_KEY or throw new Error 'BLOCKTRAIL_API_KEY required'
api_secret = process.env.BLOCKTRAIL_API_SECRET or throw new Error 'BLOCKTRAIL_API_SECRET require'

master_priv = new Buffer process.env.MASTER_KEY, 'hex'
master_pub = curve.G.multiply(BigInteger.fromBuffer master_priv).getEncoded(true)

currency = process.env.CURRENCY
{ versions } = coininfo currency

client = blocktrail.BlocktrailSDK apiKey: api_key, apiSecret: api_secret, network: 'BTC', testnet: true

load_unspent_outputs = (address, cb) ->
  client.addressUnspentOutputs address, {}, iferr cb, ({ data }) ->
    cb null, data

create_oracle_cpub = (contract_script, alice_pub, bob_pub) ->
  derive_pub master_pub, sha256 contract_script

create_multisig = (oracle_pub, alice_pub, bob_pub) ->
  pubkeys_ba = [ oracle_pub, alice_pub, bob_pub ].map (x) -> Array.apply null, x
  multisig_script = new Buffer createMultiSigOutputScript(2, pubkeys_ba, true).buffer
  scripthash = sha256ripe160 multisig_script
  multisig_addr = coinstring.encode scripthash, versions.scripthash
  multisig_addr = '2N16pTCqfPMXwMQm9gfKoRuQMETvGyznG1u'
  { multisig_script, multisig_addr }

derive_pub = (parent, chain_code) ->
  hd = new HDKey
  hd.chainCode = chain_code
  hd.publicKey = parent
  hd.deriveChild(0).publicKey

derive_priv = (parent, chain_code) ->
  hd = new HDKey
  hd.chainCode = chain_code
  hd.privateKey = parent
  hd.deriveChild(0).privateKey

module.exports = { load_unspent_outputs, create_oracle_cpub, create_multisig }


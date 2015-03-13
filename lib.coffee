iferr = require 'iferr'
BigInteger = require 'bigi'
HDKey = require 'hdkey'
#blocktrail = require 'blocktrail-sdk'
request = require 'superagent'
coinstring = require 'coinstring'
coininfo = require 'coininfo'
{ sha256, sha256ripe160 } = require 'crypto-hashing'
{ createMultiSigOutputScript } = require 'btc-script'
curve = require('ecurve').getCurveByName('secp256k1')

#api_key = process.env.BLOCKTRAIL_API_KEY or throw new Error 'BLOCKTRAIL_API_KEY required'
#api_secret = process.env.BLOCKTRAIL_API_SECRET or throw new Error 'BLOCKTRAIL_API_SECRET require'
chain_api_key = process.env.CHAIN_API_KEY

master_priv = new Buffer process.env.MASTER_KEY, 'hex'
master_pub = curve.G.multiply(BigInteger.fromBuffer master_priv).getEncoded(true)

console.log 'priv->pub - ',master_priv.toString('hex'),'->',master_pub.toString('hex')

currency = process.env.CURRENCY
{ versions } = coininfo currency

#client = blocktrail.BlocktrailSDK apiKey: api_key, apiSecret: api_secret, network: 'BTC', testnet: true

load_unspent_outputs = (address, cb) ->
  request.get "https://api.chain.com/v2/testnet3/addresses/#{ address }/unspents?api-key-id=#{ chain_api_key }"
    .end iferr cb, (res) ->
      return cb res.body or res.error if res.error
      console.log res.body
      cb null, res.body

create_oracle_keys = (contract_script, alice_pub, bob_pub) ->
  chaincode = sha256 contract_script

  pub: derive_pub master_pub, chaincode
  priv: derive_priv master_priv, chaincode

create_multisig = (oracle_pub, alice_pub, bob_pub) ->
  console.log 'multisig keys', [ oracle_pub, alice_pub, bob_pub ].map (x) -> x.toString 'hex'
  pubkeys_ba = [ oracle_pub, alice_pub, bob_pub ].map (x) -> Array.apply null, x
  multisig_script = createMultiSigOutputScript(2, pubkeys_ba, true)
  scripthash = sha256ripe160 multisig_script.buffer
  multisig_addr = coinstring.encode scripthash, versions.scripthash
  # multisig_addr = '2N16pTCqfPMXwMQm9gfKoRuQMETvGyznG1u'
  { multisig_script, multisig_addr }

derive_pub = (parent, chain_code) ->
  console.log 'derive pub with chain', parent.toString('hex'), '->', chain_code.toString 'hex'
  hd = new HDKey
  hd.chainCode = chain_code
  hd.publicKey = parent
  hd.deriveChild(0).publicKey

derive_priv = (parent, chain_code) ->
  hd = new HDKey
  hd.chainCode = chain_code
  hd.privateKey = parent
  hd.deriveChild(0).privateKey

module.exports = { load_unspent_outputs, create_oracle_keys, create_multisig }


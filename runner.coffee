{ Transaction } = require 'btc-transaction'
iferr = require 'iferr'
CoffeeScript = require 'coffee-script'
sign_multisig = require './sign-multisig'
currency = process.env.CURRENCY
tx_fees = 10000

# map from coininfo currency names to the ones used by btc-transaction/btc-address
currency_map = BTC: 'mainnet', 'BTC-TEST': 'testnet'

make_env = (privkey, multisig_script, multisig_addr, outputs) ->
  spend_all_tx = ->
    tx = new Transaction
    tx.addInput { hash }, index for { hash, index } in outputs
    tx

  sign_tx = (tx) ->
    tx = sign_multisig privkey, tx, multisig_script

    #privkey2 = new Buffer 'b87fa6019eef35760b994f71e054344329f5b76b7aff878c06dc8ebab00c191a', 'hex'
    #tx = sign_multisig privkey2, tx, multisig_script

    tx

  payto = (address) ->
    return 'No contract funds to spent.' unless outputs.length
    tx = spend_all_tx()
    if typeof address is 'string'
      total_in = 0
      total_in += value for { value } in outputs
      tx.addOutput address, total_in-tx_fees, currency_map[currency]
    else
      tx.addOutput addr, value, currency_map[currency] for addr, value of address
    sign_tx tx

  { spend_all_tx, sign_tx, payto, multisig_script, multisig_addr, outputs, Transaction }

execute = (script, env, cb) ->
  script = CoffeeScript.compile script
  # console.log 'execute with', env
  console.log 'script', script
  cb = do (cb) -> iferr cb, (res) ->
    if res.serialize? # monkey patching for tx objects
      cb null, type: 'tx', tx: new Buffer(res.serialize()).toString 'hex'
    else if typeof res is 'string'
      cb null, type: 'msg', message: res
    else
      cb new Error 'unknown contract output'
  eval "!function($, payto, out){#{ script }}(env, env.payto, cb)"

module.exports = { make_env, execute }

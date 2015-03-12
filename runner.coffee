{ Transaction } = require 'btc-transaction'
currency = process.env.CURRENCY
tx_fees = 10000

master_priv = new Buffer process.env.MASTER_KEY, 'hex'

# map from coininfo currency names to the ones used by btc-transaction/btc-address
currency_map = BTC: 'mainnet', 'BTC-TEST': 'testnet'

make_env = (multisig_script, multisig_addr, outputs) ->
  spend_all_tx = ->
    tx = new Transaction
    tx.addInput { hash }, index for { hash, index } in outputs
    tx

  sign_tx = (tx) ->
    privkey = derive_privkey master_priv, sha256 script

  payto = (address) ->
    tx = spend_all_tx()
    if typeof address is 'string'
      total_in = 0
      total_in += value for { value } in outputs
      tx.addOutput address, total_in-tx_fees, currency_map[currency]
    else
      tx.addOutput addr, value, currency_map[currency] for addr, value of address
    tx

  { spend_all_tx, payto, multisig_script, multisig_addr }

execute = (script, env, cb) ->
  console.log 'execute with', env
  console.log 'script', script
  eval "!function($, payto, out){#{ script }}(env, env.payto, cb)"

module.exports = { make_env, execute }

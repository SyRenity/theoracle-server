iferr = require 'iferr'
bodyParser = require 'body-parser'

{ load_unspent_outputs, create_oracle_keys, create_multisig } = require './lib'
{ make_env, execute } = require './runner'

((ctx, fn) -> fn.call ctx) (do require 'express'), ->
  @set 'port', process.env.PORT or 5677
  
  @use bodyParser.json()
  @use bodyParser.urlencoded extended: false

  @post '/', (req, res, next) ->
    { script, alice_pub, bob_pub } = req.body
    alice_pub = new Buffer alice_pub, 'hex'
    bob_pub = new Buffer bob_pub, 'hex'

    { pub: oracle_pub, priv: oracle_priv } = create_oracle_keys script, alice_pub, bob_pub
    { multisig_script, multisig_addr } = create_multisig oracle_pub, alice_pub, bob_pub

    load_unspent_outputs multisig_addr, iferr next, (outputs) ->
      #console.log 'multisig script', new Buffer(multisig_script.buffer).toString('hex')
      #console.log 'multisig addr', multisig_addr
      env = make_env oracle_priv, multisig_script, multisig_addr, outputs
      try execute script, env, iferr next, (tx) ->
        if tx?.serialize?
          res.send new Buffer(tx.serialize()).toString 'hex'
        else res.sendStatus 400
      catch err then next err

  @listen @settings.port, =>
    console.log "Listening on #{ @settings.port }"

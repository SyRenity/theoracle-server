iferr = require 'iferr'
bodyParser = require 'body-parser'

{ load_unspent_outputs, create_oracle_cpub, create_multisig } = require './lib'
{ make_env, execute } = require './runner'

((ctx, fn) -> fn.call ctx) (do require 'express'), ->
  @set 'port', process.env.PORT or 5677
  
  @use bodyParser.json()
  @use bodyParser.urlencoded extended: false

  @post '/', (req, res, next) ->
    { script, alice_pub, bob_pub } = req.body
    alice_pub = new Buffer alice_pub, 'hex'
    bob_pub = new Buffer bob_pub, 'hex'

    oracle_pub = create_oracle_cpub script, alice_pub, bob_pub
    { multisig_script, multisig_addr } = create_multisig oracle_pub, alice_pub, bob_pub

    load_unspent_outputs multisig_addr, iferr next, (outputs) ->
      env = make_env multisig_script, multisig_addr, outputs
      try execute script, env, iferr next, (tx) ->
        res.send tx
      catch err then next err

  @listen @settings.port, =>
    console.log "Listening on #{ @settings.port }"

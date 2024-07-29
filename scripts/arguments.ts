import { Constants } from "../misc/Constants"

// Change me to the network you want to deploy to
const config = Constants['maticmum'];

module.exports = [
  config.DEPLOYER_ADDRESS,
  config.HOST_SUPERFLUID_ADDRESS,
  config.CFA_SUPERFLUID_ADDRESS,
  config.IDA_SUPERFLUID_ADDRESS,
  config.SF_REG_KEY,
  config.GELATO_OPS,
];

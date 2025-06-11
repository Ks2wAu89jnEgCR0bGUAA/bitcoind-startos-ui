import { types as T, healthUtil } from "../dependencies.ts";

export const health: T.ExpectedExports.health = {
  "web-ui": healthUtil.checkWebUrl("http://bitcoind.embassy:5006")
}

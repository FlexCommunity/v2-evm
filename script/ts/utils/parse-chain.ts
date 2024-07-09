import { Command } from "commander";
import { findChainByName } from "../entities/chains";

export function passChainArg(fnMain:Function) {
    const program = new Command();
    program.requiredOption("--chain <chain>", "chain alias");
    const opts = program.parse(process.argv).opts();
    const chain = findChainByName(opts.chain);
    fnMain(chain.id!)
        .then(() => {
        process.exit(0);
    })
        .catch((e:any) => {
        console.error(e);
        process.exit(1);
    });
}
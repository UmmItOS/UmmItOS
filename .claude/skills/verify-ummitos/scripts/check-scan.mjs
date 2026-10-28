#!/usr/bin/env node
// check-scan.mjs: the QR panel must name the host a browser opens. Runs Scan.qml's own describe()
// on tricky links and compares its Host field with WHATWG URL parsing (what Firefox and Chromium use).
// Usage: node .claude/skills/verify-ummitos/scripts/check-scan.mjs   (exit 0 = all agree)
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const repo = fileURLToPath(new URL("../../../../", import.meta.url));
const src = readFileSync(repo + "configs/quickshell/scan/Scan.qml", "utf8");

// The QML functions are plain JS once their type annotations are stripped.
function lift(name) {
    const start = src.indexOf(`    function ${name}(`);
    if (start < 0) throw new Error(`Scan.qml has no function ${name}`);
    let depth = 0;
    for (let i = src.indexOf("{", start); i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}" && --depth === 0) {
            return src.slice(start, i + 1).replace(/\(([^)]*)\)\s*:\s*[A-Za-z]+\s*\{/, (_, args) => `(${args.replace(/:\s*[A-Za-z]+/g, "")}) {`).trim();
        }
    }
    throw new Error(`unbalanced braces in ${name}`);
}
const describe = new Function(`${lift("decode")}\n${lift("pairs")}\n${lift("describe")}\nreturn describe;`)();

const links = [
    "https://bank.example/login",
    "https://user:pw@bank.example/x",
    "https://evil.example\\@bank.example/login",
    "https:///evil.example",
    "https://\\evil.example/x",
    "https:///bank.example@evil.example",
    "https://\\/evil.example",
    "https://BANK.Example/x",
    "https://bank%2Eexample/",
    "https://bank.example:8443/x",
];

let failed = 0;
for (const link of links) {
    const shown = describe(link);
    const host = (shown.fields ?? []).find(f => f[0] === "Host")?.[1] ?? "";
    const browser = new URL(link).hostname;
    const ok = host === browser && shown.title === browser;
    if (!ok) failed++;
    console.log(`${ok ? "ok  " : "FAIL"} ${JSON.stringify(link)} panel=${JSON.stringify(host)} title=${JSON.stringify(shown.title)} browser=${JSON.stringify(browser)}`);
}
console.log(failed ? `${failed} of ${links.length} links are labelled with a host the browser would not open` : `all ${links.length} links agree`);
process.exit(failed ? 1 : 0);

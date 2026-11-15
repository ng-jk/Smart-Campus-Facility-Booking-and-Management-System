const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

async function verifyExpiry() {
    const base = process.env.CAMPUS_BASE_URL || "http://localhost:41620";
    const evidence = path.resolve(process.env.CAMPUS_EVIDENCE || "evidence");
    const browser = await chromium.launch({
        headless: true,
        executablePath: process.env.CAMPUS_BROWSER || undefined
    });
    try {
        fs.mkdirSync(evidence, { recursive: true });
        const page = await browser.newPage({ viewport: { width: 1320, height: 810 } });
        await page.goto(base + "/Login.aspx");
        await page.getByLabel("Username").fill("staff.demo");
        await page.getByLabel("Password").fill("CampusDemo-2026!");
        await page.getByRole("button", { name: "Sign in", exact: true }).click();
        await page.getByRole("heading", { name: "Find a facility" }).waitFor();
        await page.waitForTimeout(75000);
        await page.goto(base + "/History.aspx");
        assert.match(page.url(), /Login\.aspx\?reason=signin/);
        await page.getByText("Your previous session may have expired.", { exact: false }).waitFor();
        await page.screenshot({ path: path.join(evidence, "11-session-expired.png") });
        const actual = "T18 PASS: The signed-in staff session was idle for 75 seconds with the QA timeout set to one minute. History redirected to sign-in.";
        fs.writeFileSync(path.join(evidence, "expiry-result.txt"), actual + "\n");
        console.log(actual);
    } finally {
        await browser.close();
    }
}
verifyExpiry().catch(error => { console.error(error); process.exitCode = 1; });

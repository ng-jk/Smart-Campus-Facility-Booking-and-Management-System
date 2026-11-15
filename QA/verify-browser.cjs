const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const base = process.env.CAMPUS_BASE_URL || "http://localhost:41620";
const evidence = path.resolve(process.env.CAMPUS_EVIDENCE || "evidence");
const password = "CampusDemo-2026!";
const stamp = Date.now().toString().slice(-7);
const room = "QA Seminar " + stamp;
const report = [];
fs.mkdirSync(evidence, { recursive: true });

function passed(id, actual) {
    report.push({ id, actual });
    console.log(id + " " + actual);
}

async function open(page, url) {
    return page.goto(base + url, { waitUntil: "domcontentloaded" });
}

async function expectText(locator, content) {
    await locator.getByText(content, { exact: false }).first().waitFor({ timeout: 8000 });
}

async function signIn(page, account, secret = password) {
    await open(page, "/Login.aspx");
    await page.getByLabel("Username").fill(account);
    await page.getByLabel("Password").fill(secret);
    await page.getByRole("button", { name: "Sign in", exact: true }).click();
}

async function shot(page, filename) {
    await page.screenshot({ path: path.join(evidence, filename), fullPage: true, animations: "disabled" });
}

async function draft(page, beginning, purpose) {
    await open(page, "/Booking.aspx");
    await page.getByLabel("Facility", { exact: true }).selectOption({ label: room });
    await page.getByRole("button", { name: "Check availability" }).click();
    const slot = page.getByLabel("Time slot");
    const value = await slot.locator("option").nth(beginning).getAttribute("value");
    await slot.selectOption(value);
    await page.getByLabel("Purpose").fill(purpose);
}

async function queue(admin, status, purpose) {
    await open(admin, "/Admin.aspx");
    await admin.getByLabel("Search by requester or facility").fill(room);
    await admin.getByLabel("Status", { exact: true }).selectOption({ label: status });
    await admin.getByRole("button", { name: "Apply filters" }).click();
    return admin.getByRole("row").filter({ hasText: purpose });
}

async function main() {
    const browser = await chromium.launch({
        headless: true,
        executablePath: process.env.CAMPUS_BROWSER || undefined
    });
    const options = { viewport: { width: 1320, height: 810 }, reducedMotion: "reduce" };
    try {
        const student = await (await browser.newContext(options)).newPage();
        const staff = await (await browser.newContext(options)).newPage();
        const admin = await (await browser.newContext(options)).newPage();

        await open(student, "/History.aspx");
        assert.match(student.url(), /Login\.aspx\?reason=signin/);
        passed("T01", "Anonymous request redirected from booking history to sign-in.");
        await shot(student, "01-sign-in.png");

        await signIn(student, "student.demo", "incorrect-demo-password");
        await expectText(student, "The username or password is incorrect.");
        passed("T02", "Invalid password was refused with the generic sign-in message.");

        await signIn(student, "student.demo");
        await signIn(staff, "staff.demo");
        await signIn(admin, "admin.demo");
        await expectText(student, "Aisha Student · Student");
        await expectText(staff, "Ravi Staff");
        await expectText(admin, "Campus Administrator");
        passed("T03", "All three demo accounts authenticated and landed on their role-specific pages.");

        const denied = await open(student, "/Admin.aspx");
        assert.equal(denied.status(), 403);
        await expectText(student, "Access denied");
        const adminDenied = await open(admin, "/Booking.aspx");
        assert.equal(adminDenied.status(), 403);
        passed("T04", "Student was denied the administration page and administrator was denied the booking screen.");
        await shot(student, "02-access-denied.png");

        await open(admin, "/Admin.aspx?view=facilities");
        await admin.getByLabel("Facility name").fill(room);
        await admin.getByLabel("Facility type").selectOption({ label: "Meeting room" });
        await admin.getByLabel("Location").fill("Library, Level 1");
        await admin.getByLabel("Seats").fill("18");
        await admin.getByRole("button", { name: "Save facility" }).click();
        await expectText(admin, "Facility saved.");
        const facilityRow = admin.getByRole("row").filter({ hasText: room });
        await facilityRow.getByRole("button", { name: "Edit" }).click();
        await admin.getByLabel("Seats").fill("22");
        await admin.getByRole("button", { name: "Save facility" }).click();
        await expectText(facilityRow, "22");
        passed("T05", "Administrator created a facility and updated its capacity from 18 to 22.");

        await open(student, "/Booking.aspx");
        await student.getByLabel("Search by name or location").fill(room);
        await student.getByLabel("Facility type").selectOption({ label: "Meeting room" });
        await student.getByRole("button", { name: "Search", exact: true }).click();
        assert.equal(await student.locator("article.room").count(), 1);
        await expectText(student.locator("article.room"), room);
        await shot(student, "03-facility-search.png");
        passed("T06", "The name and type filters returned the matching active facility only.");

        await draft(student, 1, "");
        await student.getByRole("button", { name: "Submit request" }).click();
        await expectText(student, "Choose a time slot and enter a purpose");
        passed("T07", "A missing booking purpose was refused by server validation.");

        await draft(student, 1, "Course design workshop");
        await draft(staff, 1, "Staff planning session");
        await shot(student, "04-booking-form.png");
        await Promise.all([
            student.getByRole("button", { name: "Submit request" }).click(),
            staff.getByRole("button", { name: "Submit request" }).click()
        ]);
        const winner = /History/.test(student.url()) ? student : staff;
        const loser = winner === student ? staff : student;
        const purpose = winner === student ? "Course design workshop" : "Staff planning session";
        await expectText(winner, "was submitted for review");
        await expectText(loser, "That slot is already held");
        await shot(loser, "05-slot-conflict.png");
        passed("T08", "Two separate sessions submitted the same held slot. Exactly one got a booking ID and the other got the conflict message.");

        await open(loser, "/History.aspx");
        assert.equal(await loser.getByText(purpose, { exact: true }).count(), 0);
        passed("T09", "The successful request was absent from the other account’s booking history.");

        const pending = await queue(admin, "Pending", purpose);
        await pending.waitFor();
        await shot(admin, "06-review-queue.png");
        await pending.getByRole("button", { name: "Approve" }).click();
        await expectText(admin, "Booking approved.");
        await open(winner, "/History.aspx");
        const winnerRow = winner.getByRole("row").filter({ hasText: purpose });
        await expectText(winnerRow, "Approved");
        assert.match(await winnerRow.innerText(), /\d{2}:\d{2}–\d{2}:\d{2}/);
        await shot(winner, "07-approved-history.png");
        passed("T10", "An administrator approved the pending request and the owner saw Approved in history.");

        await open(admin, "/Admin.aspx?view=report");
        const usage = admin.getByRole("row").filter({ hasText: room });
        assert.deepEqual((await usage.locator("td").allTextContents()).slice(1).map(s => s.trim()), ["1","0","1","0","0","1"]);
        await shot(admin, "08-usage-report.png");
        passed("T11", "The facility report showed one request, one approval and one approved hour.");

        await open(admin, "/Admin.aspx?view=facilities");
        await admin.getByRole("row").filter({ hasText: room }).getByRole("button", { name: "Deactivate" }).click();
        await expectText(admin, "Resolve future bookings");
        passed("T12", "An approved future booking prevented facility deactivation.");

        await winnerRow.getByRole("button", { name: "Cancel booking" }).click();
        await expectText(winnerRow, "Cancelled");
        await shot(winner, "09-cancelled.png");
        await draft(loser, 1, "Slot released after cancellation");
        await loser.getByRole("button", { name: "Submit request" }).click();
        await expectText(loser, "was submitted for review");
        passed("T13", "The owner cancelled an approved request and the other account reused its released slot.");

        const next = await queue(admin, "Pending", "Slot released after cancellation");
        await next.getByRole("button", { name: "Reject" }).click();
        await expectText(admin, "Booking rejected.");
        await open(loser, "/History.aspx");
        await expectText(loser.getByRole("row").filter({ hasText: "Slot released after cancellation" }), "Rejected");
        passed("T14", "The rejected request appeared in the owner’s history with Rejected status.");

        await open(admin, "/Admin.aspx?view=facilities");
        const deactivated = admin.getByRole("row").filter({ hasText: room });
        await deactivated.getByRole("button", { name: "Deactivate" }).click();
        await expectText(admin, "Facility deactivated.");
        await expectText(deactivated, "Inactive");
        await open(student, "/Booking.aspx");
        assert.equal(await student.getByLabel("Facility", { exact: true }).getByRole("option", { name: room, exact: true }).count(), 0);
        passed("T15", "Deactivation hid the room from bookers after its active reservations were resolved.");

        await student.getByRole("button", { name: "Sign out" }).click();
        await expectText(student, "You have signed out.");
        await open(student, "/Booking.aspx");
        assert.match(student.url(), /Login\.aspx\?reason=signin/);
        passed("T16", "Logout cleared access and a fresh request for Facilities redirected to sign-in.");

        const mobile = await (await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true })).newPage();
        await signIn(mobile, "staff.demo");
        await expectText(mobile, "Find a facility");
        assert.equal(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
        await shot(mobile, "10-mobile.png");
        passed("T17", "The staff facility screen fit a 390-pixel viewport without page-level horizontal scrolling.");
    } finally {
        fs.writeFileSync(path.join(evidence, "browser-results.json"), JSON.stringify(report, null, 2) + "\n");
        await browser.close();
    }
}

main().catch(error => { console.error(error); process.exitCode = 1; });

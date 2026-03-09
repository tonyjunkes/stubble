<cfscript>
stubble = new models.Stubble();

function printCase(required string title, required string template, required any data, struct partials = {}) {
	output = stubble.render(arguments.template, arguments.data, arguments.partials);
	writeOutput("<h3>" & arguments.title & "</h3>");
	writeOutput("<b>Template</b><pre>" & encodeForHTML(arguments.template) & "</pre>");
	writeOutput("<b>Rendered Output</b><div>" & output & "</div>");
	writeOutput("<b>Rendered HTML</b><pre>" & encodeForHTML(output) & "</pre>");
}

function readExampleTemplate(required string relativePath) {
	return fileRead(expandPath("./templates/#arguments.relativePath#"));
}

writeOutput("<h1>Stubble Demo: File Template + File Partial</h1>");
writeOutput('<p><a href="index.cfm">Back to main demo</a></p>');

detailedTemplate = readExampleTemplate("releaseReport.mustache");
detailedProjectCardPartial = readExampleTemplate("partials/projectCard.mustache");

printCase(
	title = "File Template + File Partial + Complex Data",
	template = detailedTemplate,
	data = {
		report: {
			title: "Q2 Release Readiness",
			generatedAt: dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")
		},
		team: {
			name: "Platform Engineering",
			timezone: "UTC-05:00",
			leads: [
				{ name: "Ada Lovelace", role: "Tech Lead", email: "ada@example.com" },
				{ name: "Linus Torvalds", role: "Delivery Lead", email: "linus@example.com" }
			]
		},
		projects: [
			{
				code: "API-102",
				name: "Catalog API Revamp",
				status: "In Progress",
				owner: { name: "Grace Hopper", email: "grace@example.com" },
				summary: "Adds regional failover and schema versioning.",
				notesHtml: "<strong>Attention:</strong> Requires a coordinated migration window.",
				milestones: [
					{ name: "Schema freeze", targetDate: "2026-03-10", state: "Done" },
					{ name: "Performance soak", targetDate: "2026-03-15", state: "In Progress" },
					{ name: "Production cutover", targetDate: "2026-03-28", state: "Planned" }
				],
				services: [
					{
						name: "Search",
						tier: "Critical",
						endpointLabels: [
							{ value: "/v2/search", isLast: false },
							{ value: "/v2/suggest", isLast: true }
						]
					},
					{
						name: "Inventory",
						tier: "High",
						endpointLabels: [
							{ value: "/v1/inventory", isLast: false },
							{ value: "/v1/inventory/summary", isLast: true }
						]
					}
				],
				riskFlags: ["Data backfill duration unknown", "Third-party API throttling"]
			},
			{
				code: "WEB-88",
				name: "Checkout Reliability",
				status: "Ready For QA",
				owner: { name: "Margaret Hamilton", email: "margaret@example.com" },
				summary: "Hardens retry behavior and payment reconciliation.",
				notesHtml: "<em>Stable build</em> in staging with synthetic traffic.",
				milestones: [
					{ name: "Retry policy rollout", targetDate: "2026-03-12", state: "Done" },
					{ name: "Chaos testing", targetDate: "2026-03-20", state: "Planned" }
				],
				services: [
					{
						name: "Payments",
						tier: "Critical",
						endpointLabels: [
							{ value: "/v3/charge", isLast: false },
							{ value: "/v3/refund", isLast: true }
						]
					}
				],
				riskFlags: []
			}
		],
		unassignedBugs: [
			{ id: "BUG-4112", summary: "Intermittent timeout on cart merge", severity: "High" },
			{ id: "BUG-4189", summary: "Discount code not persisted across redirects", severity: "Medium" }
		]
	},
	partials = {
		projectCard: detailedProjectCardPartial
	}
);

stats = stubble.getCacheStats();
writeOutput("<h3>Cache Stats</h3>");
writeOutput("<pre>" & serializeJSON(stats) & "</pre>");
</cfscript>

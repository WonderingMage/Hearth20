# Windows release trust

The 0.3.16 portable and the bundled Hearth20UpdateHost.exe are Authenticode-unsigned. The user's friend reports a completed download followed by an unavailable restart and a McAfee blocked-download notification. This suggests the downloaded executable or extracted restart helper is being blocked at use time; the exact McAfee detection and file path have not been obtained. Do not label this a confirmed false positive without vendor analysis.

Hearth20 cannot declare itself trusted, bypass a quarantine, install antivirus exclusions, or grant reputation from its UI. Its updater checks GitHub and edition-manifest SHA-256 digests, checks the staged executable again before restart, checks the written helper, and leaves the running copy intact if Windows denies these operations. Hashes establish expected bytes, not an antivirus verdict.

For distribution, obtain a verified Windows publisher identity (Azure Artifact Signing or a CA-issued code-signing certificate), sign the custom native helpers before packing them, then Authenticode-sign and timestamp the completed portable after export/resource changes and before calculating release hashes. Verify the signatures before publishing. A self-signed certificate is not a public trust solution. Signing improves publisher attribution and continuity; it does not guarantee McAfee or SmartScreen approval.

Ask for the precise detection name, product version, file path, release version and protection-history entry. Submit the exact affected published EXE/helper for McAfee analysis using its official dispute/allowlisting form. Include the official GitHub release URL, exact hashes, source archive and publisher contact details. Do not submit player campaigns, PNGs, cookies, browser profiles or credentials. A vendor submission is a separate user-authorized action; none was sent during this update. No signing identity or certificate purchase is implied.

Official references:

- [McAfee detection dispute and allowlisting](https://www.mcafee.com/en-us/consumer-support/dispute-detection-allowlisting.html)
- [Microsoft Windows code-signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)
- [Microsoft SmartScreen reputation for developers](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)

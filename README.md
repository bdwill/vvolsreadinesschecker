# Pure Storage VVols Readiness Checker

This script will:
* Check for Purity 5.0.9+ or 5.1.5+
* Check for vCenter 6.5+ and ESXi 6.5+
* Check that FlashArray is accessible on tcp port 8084
* Check that an NTP server is set, valid, and daemon running on ESXi hosts and that an NTP server is set and valid on FlashArray
* Check for replication, remote side needs to meet above criteria too!

All information logged to a file.

This can be run directly from PowerCLI or from a standard PowerShell prompt. PowerCLI must be installed on the local host regardless.

Supports:
* FlashArray //m and //x
* vCenter 6.5 and later
* PowerCLI 6.3 R1 or later

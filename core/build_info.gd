## Build identity shared by the main menu, bug reports and the release tooling (P5-10).
## The version comes from `application/config/version`; the channel comes from the export feature tag
## (`demo`, `rc`) or from the debug flag, so a demo build can never call itself a release build.
## Authority: LOCAL
class_name BuildInfo
extends RefCounted

const FALLBACK_VERSION: String = "0.0.0-dev"
const DEMO_VERSION: String = "0.9.0-demo.1"
## GitHub issue form used by the in-game reporter. Keeping the URL here means one place to change it.
const GITHUB_ISSUES_URL: String = "https://github.com/AdnanMohammed0/911-The-Last-Call/issues/new?template=bug_report.yml"
## Community invite. It is intentionally empty until the server exists; the Discord button stays hidden
## while this is empty. Set it before the release candidate is handed to the community.
const DISCORD_INVITE_URL: String = ""


## Project version, e.g. `1.0.0-rc.1`. Never returns an empty string.
static func version() -> String:
	var raw: Variant = ProjectSettings.get_setting("application/config/version", FALLBACK_VERSION)
	var value: String = str(raw).strip_edges()
	return version_for_channel(channel(), value)


static func version_for_channel(build_channel: String, project_version: String) -> String:
	if build_channel == "demo":
		return DEMO_VERSION
	return project_version if not project_version.is_empty() else FALLBACK_VERSION


## Build channel: `demo`, `rc`, `release` or `dev` (editor / debug export).
static func channel() -> String:
	if OS.has_feature("demo"):
		return "demo"
	if OS.has_feature("rc"):
		return "rc"
	if OS.is_debug_build():
		return "dev"
	return "release"


## Short line shown in the menu footer and attached to bug reports.
static func label() -> String:
	return "BUILD %s · %s" % [version(), channel().to_upper()]


## Machine-readable identity for diagnostics.
static func as_dict() -> Dictionary:
	return {
		"version": version(),
		"channel": channel(),
		"engine": str(Engine.get_version_info().get("string", "")),
		"platform": OS.get_name(),
	}


static func has_discord_invite() -> bool:
	return not DISCORD_INVITE_URL.strip_edges().is_empty()

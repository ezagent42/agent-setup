# product-manager-skills (wrapper)

This is a wrapper plugin for [deanpeters/Product-Manager-Skills](https://github.com/deanpeters/Product-Manager-Skills) which does not yet have native `.claude-plugin` support.

## Maintenance

To update from upstream:
1. Clone or fetch latest from `https://github.com/deanpeters/Product-Manager-Skills`
2. Copy skill files into `skills/` directory here
3. Update `upstream.commit` in `.claude-plugin/plugin.json`
4. Commit and push

When the upstream repo adds native `.claude-plugin` support, this wrapper should be removed and replaced with a `source: url` entry in the marketplace manifest.

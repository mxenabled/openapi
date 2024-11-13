*This project is currently in **Beta**. Please open up an issue [here](https://github.com/mxenabled/openapi/issues) to report any differences in behavior between the MX Platform API and the OpenAPI specification.*

# MX's OpenAPI Specification

This repository contains the OpenAPI specification for the [MX Platform API](https://docs.mx.com/api). Changes here will also need to be added to [Docs-V2](https://gitlab.com/mxtechnologies/mx/developer-experience/projects/docs-v2); they are not currently auto-synced.

### Development

Run the command `bundle` to install the gems required to run the CI validations locally.

After making changes, running the command `bundle exec rake normalize` will run the CI validations locally.

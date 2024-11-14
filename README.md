*This project is currently in **Beta**. Please open up an issue [here](https://github.com/mxenabled/openapi/issues) to report any differences in behavior between the MX Platform API and the OpenAPI specification.*

# MX's OpenAPI Specification

This repository contains the OpenAPI specification for the [MX Platform API](https://docs.mx.com/api). Changes here will also need to be added to the MX doc site; they are not currently auto-synced.

# Client Libraries

To keep the client SDKs up to date with any changes made here, please see Platform API SDK Client Libraries article in Confluence.

### Development

Run the command `bundle` to install the gems required to run the CI validations locally.

After making changes, running the command `bundle exec rake normalize` will run the CI validations locally.

# Disconnect from the Hansard database

Closes the package connection, if one is open. Safe to call at any time.

## Usage

``` r
db_disconnect()
```

## Value

`TRUE` if a connection was closed, `FALSE` otherwise, invisibly.

## Examples

``` r
db_connect(sample = TRUE)
db_disconnect()
```

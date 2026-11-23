# dataset/

This folder holds the full Australian Hansard database, `hansard.duckdb`, for the worked
example in `example/` and for your own code. It is about 9.5 GB, and it is not loaded into
memory: ausparl queries it on disk.

## Getting the database

Either:

- download it with ausparl, from the top folder of this repository:

  ```r
  ausparl::db_download(dir = "dataset")
  ```

  The download checks the file's checksum, and an interrupted download resumes when you run the
  same line again; or

- copy a `hansard.duckdb` file you were given into this folder.

Then open it with:

```r
library(ausparl)
db_connect(path = "dataset/hansard.duckdb")
```

## Not tracked by git

The database files here (`*.duckdb`, and the `*.part` and `*.verified` files a download
leaves) are ignored by git. Only this README is part of the repository.

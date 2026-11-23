# No test may find a database downloaded into the real user data directory, so for the whole run
# it points at an empty temp directory.
withr::local_envvar(
  R_USER_DATA_DIR = withr::local_tempdir(.local_envir = testthat::teardown_env()),
  .local_envir = testthat::teardown_env()
)

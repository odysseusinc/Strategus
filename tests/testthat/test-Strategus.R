test_that("Run Eunomia study", {
  # NOTE: Need to set this in each test otherwise it goes out of scope
  renv:::renv_scope_envvars(RENV_PATHS_CACHE = renvCachePath)

  # Setup keyring for the test
  Sys.setenv("STRATEGUS_KEYRING_PASSWORD" = keyringPassword)
  createKeyringForUnitTest(selectedKeyring = keyringName, selectedKeyringPassword = keyringPassword)
  on.exit(deleteKeyringForUnitTest())

  # Using a named and secured keyring
  Strategus::storeConnectionDetails(
    connectionDetails = connectionDetails,
    connectionDetailsReference = dbms,
    keyringName = keyringName
  )

  analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
    fileName = system.file("testdata/analysisSpecification.json",
      package = "Strategus"
    )
  )

  # Create a unique set of cohort tables for this test run and
  # ensure they are removed when complete
  cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = paste0("s", tableSuffix))
  withr::defer(
    {
      CohortGenerator::dropCohortStatsTables(
        connectionDetails = connectionDetails,
        cohortDatabaseSchema = workDatabaseSchema,
        cohortTableNames = cohortTableNames,
        dropCohortTable = TRUE
      )
      unlink(file.path(tempDir, "EunomiaTestStudy"), recursive = TRUE, force = TRUE)
    },
    testthat::teardown_env()
  )

  # Use this line to limit to only running the CohortGeneratorModule
  # for testing purposes.
  analysisSpecifications$moduleSpecifications <- analysisSpecifications$moduleSpecifications[-c(2:length(analysisSpecifications$moduleSpecifications))]
  executionSettings <- createCdmExecutionSettings(
    connectionDetailsReference = dbms,
    workDatabaseSchema = workDatabaseSchema,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortTableNames = cohortTableNames,
    workFolder = file.path(tempDir, "EunomiaTestStudy/work_folder"),
    resultsFolder = file.path(tempDir, "EunomiaTestStudy/results_folder"),
    minCellCount = 5
  )

  if (!dir.exists(file.path(tempDir, "EunomiaTestStudy"))) {
    dir.create(file.path(tempDir, "EunomiaTestStudy"), recursive = TRUE)
  }
  ParallelLogger::saveSettingsToJson(
    object = executionSettings,
    file.path(tempDir, "EunomiaTestStudy/eunomiaExecutionSettings.json")
  )

  executionSettings <- ParallelLogger::loadSettingsFromJson(
    fileName = file.path(tempDir, "EunomiaTestStudy/eunomiaExecutionSettings.json")
  )

  Strategus::execute(
    analysisSpecifications = analysisSpecifications,
    executionSettings = executionSettings,
    executionScriptFolder = file.path(tempDir, "EunomiaTestStudy/script_folder"),
    keyringName = keyringName
  )

  expect_true(file.exists(file.path(tempDir, "EunomiaTestStudy/results_folder/CohortGeneratorModule_1/done")))
})

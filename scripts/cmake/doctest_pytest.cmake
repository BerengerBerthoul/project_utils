function(create_doctest)
  include(CTest)
  set(options)
  set(one_value_args)
  set(multi_value_args TESTED_TARGET LABEL SOURCES SERIAL_RUN N_PROC)
  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})
  set(tested_target ${ARGS_TESTED_TARGET})
  set(label ${ARGS_LABEL})
  set(sources ${ARGS_SOURCES})
  set(serial_run ${ARGS_SERIAL_RUN})
  set(n_proc ${ARGS_N_PROC})

  set(test_name "${tested_target}_doctest_${label}")
  add_executable(${test_name} ${sources})

  target_link_libraries(${test_name}
    PUBLIC
      ${tested_target}::${tested_target}
    PRIVATE
      doctest::doctest
  )

  install(TARGETS ${test_name} RUNTIME DESTINATION bin)
  if(${serial_run})
    add_test(
      NAME ${test_name}
      COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${test_name}
    )
  else()
    add_test(
      NAME ${test_name}
      COMMAND ${MPIEXEC} ${MPIEXEC_NUMPROC_FLAG} ${n_proc}
              ${MPIEXEC_PREFLAGS}
              ${CMAKE_CURRENT_BINARY_DIR}/${test_name}
              ${MPIEXEC_POSTFLAGS}
    )
  endif()

  set_tests_properties(${test_name}
    PROPERTIES
      LABELS "${label}"
      SERIAL_RUN ${serial_run}
      PROCESSORS ${n_proc}
      #PROCESSOR_AFFINITY true # Fails in non-slurm
  )
endfunction()


function(create_pytest)
  set(options)
  set(one_value_args)
  set(multi_value_args TESTED_FOLDER LABEL SERIAL_RUN N_PROC)
  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})
  set(tested_folder ${ARGS_TESTED_FOLDER})
  set(label ${ARGS_LABEL})
  set(serial_run ${ARGS_SERIAL_RUN})
  set(n_proc ${ARGS_N_PROC})
  set(test_name "${PROJECT_NAME}_pytest_${label}")

  # Test environment
  set(ld_library_path ${PROJECT_BINARY_DIR})
  set(pythonpath ${PROJECT_BINARY_DIR}:${PROJECT_SOURCE_DIR}:${CMAKE_BINARY_DIR}/external/pytest-mpi-check)
  if (NOT MAIA_USE_PDM_INSTALL) # TODO move from here
    set(pythonpath ${CMAKE_BINARY_DIR}/external/paradigm/Cython/:${pythonpath})
  endif()

  # Don't pollute the source with __pycache__
  if (${Python_VERSION} VERSION_GREATER_EQUAL 3.8)
    set(pycache_env_var "PYTHONPYCACHEPREFIX=${PROJECT_BINARY_DIR}")
  else()
    set(pycache_env_var "PYTHONDONTWRITEBYTECODE=1")
  endif()
  set(pytest_plugins "pytest_mpi_check")

  # -r : display a short test summary info, with a == all except passed (i.e. report failed, skipped, error)
  # -s : no capture (print statements output to stdout)
  # -v : verbose
  # -Wignore : Python never warns (TODO why needed here?)
  # --rootdir : path where to put temporary test info (internal to pytest and its plugins)
  # TODO if pytest>=6, add --import-mode importlib (cleaner PYTHONPATH used by pytest)
  set(cmd pytest --rootdir=${PROJECT_BINARY_DIR} ${tested_folder} -Wignore -ra -v -s --with-mpi)
  if(${serial_run})
    add_test(
      NAME ${test_name}
      COMMAND ${cmd}
    )
  else()
    add_test(
      NAME ${test_name}
      COMMAND ${MPIEXEC} ${MPIEXEC_NUMPROC_FLAG} ${n_proc}
              ${MPIEXEC_PREFLAGS}
              ${cmd}
              ${MPIEXEC_POSTFLAGS}
    )
  endif()

  set_tests_properties(
    ${test_name}
    PROPERTIES
      LABELS "${label}"
      ENVIRONMENT "LD_LIBRARY_PATH=${ld_library_path}:$ENV{LD_LIBRARY_PATH};PYTHONPATH=${pythonpath}:$ENV{PYTHONPATH};${pycache_env_var};PYTEST_PLUGINS=pytest_mpi_check"
      SERIAL_RUN ${serial_run}
      PROCESSORS ${n_proc}
      #PROCESSOR_AFFINITY true # Fails in non-slurm, not working if not launch with srun
  )
  # TODO this one makes pytest execute nothing (pytest_mpi_check not ready)
  # ENVIRONMENT PYTEST_PLUGINS=pytest_mpi_check

  # Create pytest_source.sh with all needed env var to run pytest outside of CTest
  ## strings inside pytest_source.sh.in to be replaced
  set(PYTEST_ENV_PREPEND_LD_LIBRARY_PATH ${ld_library_path})
  set(PYTEST_ENV_PREPEND_PYTHONPATH      ${pythonpath})
  set(PYTEST_ENV_PYCACHE_ENV_VAR         ${pycache_env_var})
  set(PYTEST_ROOTDIR                     ${PROJECT_BINARY_DIR})
  set(PYTEST_PLUGINS                     ${pytest_plugins})
  configure_file(
    ${PROJECT_UTILS_CMAKE_DIR}/pytest_source.sh.in
    ${PROJECT_BINARY_DIR}/source.sh
    @ONLY
  )
endfunction()
# --------------------------------------------------------------------------------


## --------------------------------------------------------------------------------
#function(mpi_test_create target_file name tested_target n_proc )
#  set(options)
#  set(one_value_args)
#  set(multi_value_args SOURCES INCLUDES LIBRARIES LABELS SERIAL_RUN)
#  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})
#
#  add_executable(${name} ${target_file} ${ARGS_SOURCES})
#
#  target_include_directories(${name} PRIVATE ${ARGS_INCLUDES})
#  target_link_libraries(${name} ${ARGS_LIBRARIES})
#  target_link_libraries(${name} ${tested_target}::${tested_target})
#
#  install(TARGETS ${name} RUNTIME DESTINATION bin)
#  add_test (NAME ${name}
#            COMMAND ${MPIEXEC} ${MPIEXEC_NUMPROC_FLAG} ${n_proc}
#                    ${MPIEXEC_PREFLAGS}
#                    ${CMAKE_CURRENT_BINARY_DIR}/${name}
#                    ${MPIEXEC_POSTFLAGS})
#  # add_test (NAME ${name}
#  #           COMMAND ${CMAKE_CURRENT_BINARY_DIR}/${name})
#
#  # > Set properties for the current test
#  set_tests_properties(${name} PROPERTIES LABELS "${ARGS_LABELS}")
#  set_tests_properties(${name} PROPERTIES PROCESSORS nproc)
#  if(${ARGS_SERIAL_RUN})
#    set_tests_properties(${name} PROPERTIES RUN_SERIAL true)
#  endif()
#  # > Fail in non slurm
#  # set_tests_properties(${name} PROPERTIES PROCESSOR_AFFINITY true)
#
#  # > Specific environement :
#  # set_tests_properties(${name} PROPERTIES ENVIRONMENT I_MPI_DEBUG=5)
#
#endfunction()
## --------------------------------------------------------------------------------

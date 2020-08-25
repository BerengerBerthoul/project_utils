#define DOCTEST_CONFIG_IMPLEMENT
#include "std_e/unit_test/mpi/doctest.hpp"

namespace {

inline auto
mpi_init_if_needed(int argc, char** argv) -> bool {
  int flag;
  MPI_Initialized(&flag);
  bool already_init = bool(flag);

  if (!already_init) {
    MPI_Init(&argc, &argv);
  }
  return already_init;
}

}

int main(int argc, char** argv) {
  mpi_init_if_needed(argc,argv);

  doctest::Context ctx;
  ctx.setOption("reporters", "MpiConsoleReporter");
  ctx.setOption("reporters", "MpiFileReporter");
  ctx.setOption("force-colors", true);
  ctx.applyCommandLine(argc, argv);

  int test_result = ctx.run();

  MPI_Finalize();

  return test_result;
}

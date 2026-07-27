cmake_minimum_required(VERSION 3.16)

project(apibrasil_exemplos
    VERSION 1.0.0
    DESCRIPTION "Exemplos da SDK oficial C++ da APIBrasil"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---------------------------------------------------------------------------
# SDK
# ---------------------------------------------------------------------------
# Baixa a SDK na configuração. Para desenvolver contra um checkout local,
# troque este bloco por:
#     add_subdirectory(../../../apigratis-sdk-cpp apibrasil-sdk)
include(FetchContent)
FetchContent_Declare(apibrasil
    GIT_REPOSITORY https://github.com/jhowbhz/apigratis-sdk-cpp.git
    GIT_TAG v0.0.2)
FetchContent_MakeAvailable(apibrasil)

# ---------------------------------------------------------------------------
# Exemplos
# ---------------------------------------------------------------------------
set(EXEMPLOS
    01-conta-e-saldo
    02-consultas-por-credito
    03-whatsapp
    04-servicos-device
    05-erros-e-retry)

foreach(exemplo IN LISTS EXEMPLOS)
    add_executable(${exemplo} ${exemplo}.cpp)
    target_link_libraries(${exemplo} PRIVATE apibrasil::apibrasil)
endforeach()

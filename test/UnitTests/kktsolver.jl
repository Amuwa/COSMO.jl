using COSMO, Test, LinearAlgebra, SparseArrays, Random, QDLDL, Pkg
include("COSMOTestUtils.jl")

rng = Random.MersenneTwister(1)

T = Float64

# check if optional dependencies are available
test_iterative_solvers = pkg_installed("IterativeSolvers", "42fd0dbc-a981-5370-80f2-aaf504508153") && pkg_installed("LinearMaps", "7a12625a-238d-50fd-b39a-03d52299707e")
test_pardiso = pkg_installed("Pardiso", "46dd5b70-b6fb-5a00-ae2d-e8fea33afaf2")

function make_test_kkt(P, A, sigma, rho)

    R = length(rho)   == 1 ? ((1.) ./ rho[1]) * I : Diagonal((1.) ./ rho)
    S = length(sigma) == 1 ? (sigma[1]) * I : Diagonal(sigma)

    #compute the full KKT matrix
    K    = [P+S A'; A -R]
    return K
end

function add_kwargs(array; kwargs...)
    push!(array, kwargs)
end


@testset "KKT solver" begin
    solver_types = []
    solver_tols = []
    params = []
    push!(solver_types, COSMO.QdldlKKTSolver)
    push!(solver_tols, 1e-10)
    add_kwargs(params)
    push!(solver_types, COSMO.CholmodKKTSolver)
    push!(solver_tols, 1e-10)
    add_kwargs(params)

    # optional dependencies
    if test_pardiso
        using Pardiso
        if Pardiso.LOCAL_MKL_FOUND
            push!(solver_types, COSMO.MKLPardisoKKTSolver)
            push!(solver_tols, 1e-10)
                add_kwargs(params)
            end
        if Pardiso.PARDISO_LIB_FOUND
            push!(solver_types, COSMO.PardisoDirectKKTSolver)
            push!(solver_tols, 1e-10)
            add_kwargs(params)
        end
        if Pardiso.PARDISO_LIB_FOUND
            push!(solver_types, COSMO.PardisoIndirectKKTSolver)
            push!(solver_tols, 5e-5)
            add_kwargs(params)
        end
    end

    if test_iterative_solvers
        using IterativeSolvers, LinearMaps
        push!(solver_types, COSMO.IndirectReducedKKTSolver)
        push!(solver_tols, 1e-3)
        add_kwargs(params, solver_type=:CG)

        push!(solver_types, COSMO.IndirectReducedKKTSolver)
        push!(solver_tols, 1e-3)
        add_kwargs(params, solver_type=:MINRES)

        push!(solver_types, COSMO.IndirectKKTSolver)
        push!(solver_tols, 1e-3)
        add_kwargs(params, solver_type=:MINRES)
    end


    @testset "$(solver_types[i]): KKT solver tests" for i = 1:length(solver_types)

        m = 10
        n = 20

        for rho1 in [rand(T), rand(T, m)],
            rho2 in [rand(T), rand(T, m)],
            sigma in [rand(T)]

            P  = sparse(generate_pos_def_matrix(rng, n))
            A  = sprandn(m, n, 0.2)
            b = randn(m + n)

            F = solver_types[i](P, A, sigma, rho1; params[i]...)
            if test_iterative_solvers
                if isa(F, COSMO.IndirectReducedKKTSolver) || isa(F, COSMO.IndirectKKTSolver)
                    # Technically, we should have been able to set the tolerance even lower
                    # But, currently, issues in IterativeSolvers.jl do not allow this
                    # See: https://github.com/JuliaMath/IterativeSolvers.jl/pull/244
                    F.iteration_counter = 10^4 # This forces CG's/MINRES tolerance to be 1/10^4
                end
            end
            J = make_test_kkt(P, A, sigma, rho1)
            x = copy(b)

            #test a single solve
            COSMO.solve!(F, x, b)
            @test norm(x - J \ b) <= solver_tols[i]

            # Check that warm starting works
            # Invoking again an indirect solver should result in the solution with only
            # one matrix vector multiplication
            if test_iterative_solvers
                if isa(F, COSMO.IndirectReducedKKTSolver) || isa(F, COSMO.IndirectKKTSolver)
                    # The calculation of the residual, and thus the termination criterion, of
                    # MINRES is approximate. Thus warm started solutions won't necessarily finish in one step
                    # For this reason we don't check warm starting with MINRES for now :(
                    if F.solver_type != :MINRES
                        COSMO.solve!(F, x, b)
                        # @test F.multiplications[end] <= 1 uncommented as test causes non-deterministic behaviour
                        @test norm(x - J \ b) <= solver_tols[i]
                    end
                end
            end

            #test a rho update and solve
            J = make_test_kkt(P, A, sigma, rho2)
            x = copy(b)
            COSMO.update_rho!(F, rho2)
            COSMO.solve!(F, x, b)
            @test norm(x - J \ b) <= solver_tols[i]

         end

    end

    # Try every solver on the same problem and compare results
    solver_types = Array{Union{Type{<: COSMO.AbstractKKTSolver}, COSMO.OptionsFactory{<: COSMO.AbstractKKTSolver}}}(undef, 0)
    push!(solver_types, COSMO.QdldlKKTSolver, COSMO.CholmodKKTSolver)
    if test_pardiso
        Pardiso.LOCAL_MKL_FOUND && push!(solver_types, COSMO.PardisoDirectKKTSolver)
        if Pardiso.PARDISO_LIB_FOUND
            push!(solver_types, COSMO.PardisoDirectKKTSolver)
            push!(solver_types, COSMO.PardisoIndirectKKTSolver)
        end
    end
    if test_iterative_solvers
        push!(solver_types, COSMO.CGIndirectKKTSolver)
        push!(solver_types, COSMO.MINRESIndirectKKTSolver)
        push!(solver_types, with_options(COSMO.CGIndirectKKTSolver))
        push!(solver_types, with_options(COSMO.MINRESIndirectKKTSolver))
    end

     P = [4. 1;1 2]
     q = [1; 1.]
     A = [1. 1;1 0; 0 1]
     l = [1.;0;0]
     u = [1.;0.7;0.7]

     constraint1 = COSMO.Constraint(-A, u, COSMO.Nonnegatives)
     constraint2 = COSMO.Constraint(A, -l, COSMO.Nonnegatives)
     constraints = [constraint1; constraint2]
     @testset "$(solver_types[i]): KKT solver tests - simple problem" for i = 1:length(solver_types)
         model = COSMO.Model()
         settings = COSMO.Settings(kkt_solver = solver_types[i])
         assemble!(model, P, q, constraints, settings = settings)
         res = COSMO.optimize!(model);
         @test isapprox(norm(res.x - [0.3; 0.7]), 0., atol=1e-3)
         @test isapprox(res.obj_val, 1.88, atol=1e-3)

     end


     # Check the KKT triangle assembly utility functions
     @testset "KKT matrix assembly" begin
         n = 3
         m = 2
         P = sparse([1. 0 1; 0 0 1; 1 1 1])
         A = sparse([2. 2 2; 0 3 0])
         # known number of nonzero entries in upper and lower triangle of KKT matrix K
         Kcolnz_upper_sol = [1; 1; 3; 4; 2]
         Kcolnz_lower_sol = [3; 4; 2; 1; 1]
         Kcolnz_upper = zeros(Int64, m + n)
         COSMO._count_upper_triangle!(Kcolnz_upper, P, A, n)
         @test Kcolnz_upper == Kcolnz_upper_sol
         Kcolnz_lower = zeros(Int64, m + n)
         COSMO._count_lower_triangle!(Kcolnz_lower, P, A, n)
         @test Kcolnz_lower == Kcolnz_lower_sol

         # make sure all the assembly function return the same matrix K
         m = 11
         n = 15
         P  = sparse(generate_pos_def_matrix(rng, n))
         A  = sprandn(rng, m, n, 0.2)
         sigma = 1e-6
         rho = 0.1 * ones(m)
         K_full = COSMO._assemble_kkt_full(P, A, sigma, rho)
         K_tril = COSMO._assemble_kkt_triangle(P, A, sigma, rho, :L)
         K_triu = COSMO._assemble_kkt_triangle(P, A, sigma, rho, :U)
         @test triu(K_full) == K_triu
         @test tril(K_full) == K_tril
     end


end

nothing

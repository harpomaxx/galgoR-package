#' @title GSgalgoR:  A bi-objective evolutionary meta-heuristic to identify
#' robust transcriptomic classifiers associated with patient outcome across
#' multiple cancer types.
#'
#' @description This package was developed to provide a simple to use set of
#' functions to use the galgo algorithm. A multi-objective optimization
#' algorithm for disease subtype discovery based on a non-dominated sorting
#' genetic algorithm.
#'
#' Different statistical and machine learning approaches have long been
#' used to identify gene expression/molecular signatures with prognostic
#' potential in different cancer types. Nonetheless, the molecular
#' classification of tumors is a difficult task and the results obtained
#' via the current statistical methods are highly dependent on the features
#' analyzed, the number of possible tumor subtypes under consideration, and
#' the underlying assumptions made about the data. In addition, some cancer
#' types are still lacking prognostic signatures and/or of subtype-specific
#' predictors which are continually needed to further dissect tumor biology.
#' In order to identify specific molecular phenotypes to develop precision
#' medicine strategies we present Galgo: A multi-objective optimization
#' process based on a non-dominated sorting genetic algorithm that combines
#' the advantages of clustering methods for grouping heterogeneous omics data
#' and the exploratory properties of genetic algorithms (GA) in order to find
#' features that maximize the survival difference between subtypes while
#' keeping high cluster consistency.
#'
#' \tabular{ll}{ Package: \tab GSgalgoR\cr Type: \tab Package\cr
#' Version: \tab 1.0.0\cr Date: \tab 2020-05-06 \cr License: \tab GPL-3\cr
#' Copyright: \tab (c) 2020 Martin E. Guerrero-Gimenez.\cr URL: \tab
#' \url{https://www.github.com/harpomaxx/galgo}\cr LazyLoad: \tab yes\cr
#' }
#'
#' @author
#' Martin E. Guerrero-Gimenez \email{mguerrero@@mendoza-conicet.gob.ar}
#'
#' Maintainer: Carlos A. Catania \email{harpomaxx@@gmail.com }
#' @docType package
#' @name GSgalgoR-package
#' @aliases GSgalgoR-package GSgalgoR
#' @importFrom  methods new
NULL


#' Galgo Object class
#'
#' @slot Solutions matrix.
#' @slot ParetoFront list.
#'
#'
#' @export
#'
#' @examples
galgo.Obj <- setClass( # Set the name for the class
    "galgo.Obj",
    # Define the slots
    slots = c(
        Solutions = "matrix",
        ParetoFront = "list"
    )
)

setGeneric("Solutions", function(x) standardGeneric("Solutions"))
setGeneric("ParetoFront", function(x) standardGeneric("ParetoFront"))
setMethod("Solutions", "galgo.Obj", function(x) x@Solutions)
setMethod("ParetoFront", "galgo.Obj", function(x) x@ParetoFront)

#' Survival Mean
#'
#' @param x
#' @param rmean
#'
#' @return
#' @noRd
#' @examples
RMST <- function(ft, rmean) {
    nstrat <- length(ft$strata)
    stemp <- rep(seq_len(nstrat), ft$strata)
    rmst <- numeric(length(nstrat)) 
    for (i in seq_len(nstrat)) {
        who <- (stemp == i)
        idx <- ft$time[who] <= rmean
        wk.time <- sort(c(ft$time[who][idx], rmean))
        wk.surv <- ft$surv[who][idx]
        wk.n.risk <- ft$n.risk[who][idx]
        wk.n.event <- ft$n.event[who][idx]
        time.diff <- diff(c(0, wk.time))
        areas <- time.diff * c(1, wk.surv)
        rmst_x <- sum(areas)
        # rmst <- c(rmst, rmst_x)
        rmst[i] <- rmst_x
    }
    return(rmst)
}


#' create_folds splits the data into k groups to perform cross-validation
#'
#' @param y a vector of outcomes
#' @param k an integer for the number of folds
#' @param list logical - should the results be in a list (TRUE) or in a vector
#' @param returnTrain a logical. When true, the values returned are the sample
#' positions correspondingto the data used during training. This argument only
#' works in conjunction withlist = TRUE
#'
#' @return if list=TRUE, it returns a list with k elements were each element
#' of the list has the position of the outcomes included in said fold,
#' if list=FALSE the function returns a vector where each outcome is assigned
#' to a given fold from 1 to k
#'
#' @examples
#' y <- rnorm(100, 5, 2) # A vector of outcomes
#' k <- 5 # Number of folds
#' create_folds(y, k = k, list = TRUE)
#' @noRd
#'
create_folds <-
    function(y, k = 10, list = TRUE, returnTrain = FALSE) {
        if (class(y)[1] == "Surv") {y <- y[, "time"]}
        if (is.numeric(y)) {
            cuts <- floor(length(y) / k)
            if (cuts < 2) {cuts <- 2}
            if (cuts > 5) {cuts <- 5}
            breaks <-
                unique(stats::quantile(y, probs = seq(0, 1, length = cuts)))
            y <- cut(y, breaks, include.lowest = TRUE)
        }
        if (k < length(y)) {
            y <- factor(as.character(y))
            numInClass <- table(y)
            foldVector <- vector(mode = "integer", length(y))
            for (i in seq_len(length(numInClass))) {
                min_reps <- numInClass[i] %/% k
                if (min_reps > 0) {
                    spares <- numInClass[i] %% k
                    seqVector <- rep(seq_len(k), min_reps)
                    if (spares > 0) {
                        seqVector <- c(seqVector, sample(seq_len(k), spares))
                    }
                    foldVector[which(y == names(numInClass)[i])] <-
                        sample(seqVector)
                }
                else {
                    foldVector[which(y == names(numInClass)[i])] <-
                        sample(seq_len(k), size = numInClass[i]
                        )
                }
            }
        }
        else {
            foldVector <- seq(along = y)
        }
        if (list) {
            out <- split(seq(along = y), foldVector)
            names(out) <-
                paste("Fold", gsub(" ", "0", format(seq(along = out))),sep = "")
            if (returnTrain) {
                out <- lapply(out, function(data, y) {y[-data]},
                            y = seq(along = y))
            }
        }
        else {
            out <- foldVector
        }
        out
    }

#' Harmonic mean
#'
#' The harmonic mean can be expressed as the reciprocal of the arithmetic
#' mean of the reciprocals of a given set of observations.
#' Since the harmonic mean of a list of numbers tends strongly toward
#' the least elements of the list, it tends (compared to the arithmetic mean)
#' to mitigate the impact of large outliers and aggravate the impact
#' of small ones.
#'
#' @param a a numeric vector of length > 1
#'
#' @return returns the harmonic mean of the values in \code{a}
#' @noRd
#' @examples
#' x <- rnorm(5, 0, 1) # five random numbers from the normal distribution
#' x <- c(x, 20) # add outlier
#' hmean(x)
hmean <- function(a) {
    1 / mean(1 / a)
}

#' Harmonic mean of the distance between consecutive groups
#'
#' Implements the harmonic mean of the distance between consecutive
#' groups multiplied by the number of comparisons:
#' \eqn{consecutive_distance = [n/ (1/x1-x2 + 1/x2-x3 +...1/xn-1 - xn)] * n-1}
#'
#' @param x A numeric vector of length > 1
#'
#' @return The function computes the harmonic mean of the differences
#' between consecutive groups multiplied by the number of comparisons and
#' returns a positive number. This function is used inside \code{fitness}
#' function.
#' @noRd
#' @examples
#' V <- c(4.5, 3, 7, 11)
#' consecutive_distance(V)
consecutive_distance <- function(x) {
    d <- x[order(x)]
    l <- length(d) - 1
    c <- c(0, 1)
    dif <- numeric(length(l))
    for (i in seq_len(l)) {
        #dif <- c(dif, diff(d[c + i]))
        dif[i] <- diff(d[c + i])
    }
    return(hmean(dif) * l)
}




#' Survival fitness function using the Restricted Mean Survival Time (RMST)
#' of each group
#'
#' Survival fitness function using the Restricted Mean Survival Time (RMST)
#' of each group as proposed by \emph{Dehbi & Royston et al. (2017)}.
#'
#' @param OS a \code{survival} object with survival data of the patients
#' evaluated
#' @param clustclass a numeric vector with the group label for each patient
#' @param period a number representing the period of time to evaluate in the
#' RMST calculation
#'
#' @return The function computes the Harmonic mean of the differences
#' between Restricted Mean Survival Time (RMST) of consecutive survival
#' curves multiplied by the number of comparisons.
#'
#' @references Dehbi Hakim-Moulay, Royston Patrick, Hackshaw Allan. Life
#' expectancy difference and life expectancy ratio: two measures of treatment
#' effects in randomized trials with non-proportional
#' hazards BMJ 2017; 357 :j2250 \url{https://www.bmj.com/content/357/bmj.j2250}
#' @author Martin E Guerrero-Gimenez, \email{mguerrero@mendoza-conicet.gob.ar}
#' @export
#'
#' @examples
#'
#' # load example dataset
#' library(breastCancerTRANSBIG)
#' library(Biobase)
#' data(transbig)
#' Train <- transbig
#' rm(transbig)
#'
#' clinical <- pData(Train)
#' OS <- survival::Surv(time = clinical$t.rfs, event = clinical$e.rfs)
#'
#' surv_fitness(OS, clustclass = clinical$grade, period = 3650)
surv_fitness <- function(OS, clustclass, period) {
    score <- tryCatch(
        {   # This function calculates the RMST (comes from package survival)
            t <-
                RMST(survival::survfit(OS ~ clustclass), rmean = period)

            consecutive_distance(t)
        },
        error = function(e) {
            return(0)
        }
    )       # If consecutive_distance cannot be calculated,
            #the difference is set to 0 (no difference between curves)
    return(score)
}

## Helpers Functions to vectorize crossvalidation

#' Title
#'
#' @param flds
#' @param Data
#'
#' @return
#'
#' @examples
#' @noRd
build_train <- function(flds, data) {
    data[, -flds]
}

#' Title
#'
#' @param flds
#' @param Data
#'
#' @return
#'
#' @examples
#' @noRd
build_test <- function(flds, data) {
    data[, flds]
}


#' Title
#'
#' @param f
#'
#'
#' @return
#'
#' @examples
#' @noRd
#'
subset_distance <- function(flds, distance_data) {
    # sub <- subset(D, -flds) #experimental function from cba package
    # sub<- usedist::dist_subset(D, -flds)
    proxy::as.dist(proxy::as.matrix(distance_data)[-flds, -flds])
}

#' Title
#'
#' @param C
#'
#' @return
#'
#' @examples
#' @noRd
alloc2 <- function(C) {
    Ct <- t(C)
    ord <- matchingR::galeShapley.marriageMarket(C, Ct)
    return(ord$engagements)
}


#' Title
#'
#' @param C
#' @param ord
#'
#' @return
#'
#' @examples
#' @noRd
reord <- function(C, ord) {
    C <- C[, ord]
}

#' Survival crossvalidation
#'
#' crossvalidation function based on:
#' https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3105299/
#' Data is the expression matrix
#' flds is a list with the indexes to partition the data in n different folds
#' indv is the solution to test, namely, a binary vector to subset the genes
#' to test
#' The function returns two fitness: fit_1 (the mean silhouette) and
#' fit_2 (the ad-hoc function to estimate the differences between curves)

#' @param Data
#' @param flds
#' @param indv
#' @param k
#' @param surv_obj
#' @param distance
#' @param nCV
#' @param period
#'
#' @return
#'
#' @examples
#' @noRd
crossvalidation <-
    function(data,
            flds,
            indv,
            k,
            surv_obj,
            distance,
            nCV,
            period) {
        data <- data[indv, ]
        distance_data <- distance(data)
        train_a <- lapply(flds, build_train, data = data)
        test_a <- lapply(flds, build_test, data = data)
        sub <- lapply(flds, subset_distance, distance_data = distance_data)
        #hc <- sapply(sub, cluster_algorithm, k = k)
        hc <- lapply(sub, function(x,k)cluster_algorithm(x,k)$cluster, k = k)
        centroids <- mapply(k_centroids, train_a, hc, SIMPLIFY = FALSE)
        centroids_cor <- mapply(stats::cor, centroids[1], centroids[2:nCV],
                                SIMPLIFY = FALSE)
        cord <- lapply(centroids_cor, alloc2)
        cord <- append(list(as.matrix(seq_len(k), ncol = 1)), cord, 1)
        centroids <- mapply(reord, centroids, cord, SIMPLIFY = FALSE)
        class_results <- mapply(cluster_classify, test_a, centroids,
                                SIMPLIFY = FALSE)
        cluster_class <- unlist(class_results)
        cluster_class <- cluster_class[order(as.vector(unlist(flds)))]
        fit_silhouette <- mean(cluster::silhouette(cluster_class,
                                        distance_data)[, 3])
        fit_differences <- surv_fitness(surv_obj, cluster_class, period)
        return(c(fit_silhouette, fit_differences))
    }


#' Minimum number of genes to use in a solution (A constraint for the algorithm)
#'
#' @param x
#' @param chrom_length
#'
#' @return
#'
#' @examples
#' @noRd
mininum_genes <- function(x, chrom_length) {
    sum(x) >= 10 & sum(x) < chrom_length
}

#' Uniform crossover
#'
#' @param a
#' @param b
#'
#' @return
#'
#' @examples
#' @noRd
uniform_crossover <- function(a, b) {
    if (length(a) != length(b)) {
        stop("vectors of unequal length")
    }
    l <- length(a)
    points <- as.logical(stats::rbinom(l, 1, prob = stats::runif(1)))
    achild <- numeric(l)
    achild[points] <- a[points]
    achild[!points] <- b[!points]
    bchild <- numeric(l)
    bchild[points] <- b[points]
    bchild[!points] <- a[!points]
    return(list(achild, bchild))
}


#' Asymmetric mutation operator:
#' Analysis of an Asymmetric Mutation Operator; Jansen et al.
#'
#' @param x
#'
#' @return
#'
#' @examples
#' @noRd
asymetric_mutation <- function(x) {
    chrom_length <- length(x)
    res <- x
    Active <- sum(x)
    Deactive <- chrom_length - Active
    mutrate1 <- 1 / Active
    mutrate2 <- 1 / Deactive
    mutpoint1 <-
        sample(c(1, 0),
            Deactive,
            prob = c(mutrate2, 1 - mutrate2),
            replace = TRUE
        )
    res[x == 0] <- abs(x[x == 0] - mutpoint1)

    mutpoint2 <-
        sample(c(1, 0),
            Active,
            prob = c(mutrate1, 1 - mutrate1),
            replace = TRUE
        )
    res[x == 1] <- abs(x[x == 1] - mutpoint2)
    return(res)
}


#' Offspring creation
#'
#' @param X1
#' @param chrom_length
#' @param population
#' @param TournamentSize
#'
#' @return
#'
#' @examples
#' @noRd
offsprings <- function(X1,
                    chrom_length,
                    population,
                    TournamentSize) {
    # Create empty matrix to add new individuals
    New <- matrix(NA, ncol = chrom_length, nrow = population)
    # same for cluster chromosome
    NewK <- matrix(NA, nrow = 1, ncol = population)
    # Use tournament selection, to select parents that will give offsprings
    matingPool <- nsga2R::tournamentSelection(X1, population, TournamentSize)
    # Count how many offsprings are still needed to reach population size
    count <- 0
    while (anyNA(New)) {
        count <- count + 1
        ## a.Select a pair of parent chromosomes from the matingPool
        Pair <- sample(seq_len(nrow(matingPool)), 2, replace = FALSE)
        # multiple point crossingover
        offsprings <-uniform_crossover(matingPool[Pair[1],
                                            seq_len(chrom_length)],
                                            matingPool[Pair[2],
                                            seq_len(chrom_length)])
        off1 <- offsprings[[1]]
        off2 <- offsprings[[2]]
        ## c.Mutate the two offsprings at each locus with probability Mp
        Mp <- cosine_similarity(matingPool[Pair[1], seq_len(chrom_length)],
                                matingPool[Pair[2], seq_len(chrom_length)])
        if (sample(c(1, 0), 1, prob = c(Mp, 1 - Mp)) == 1) {
            off1 <- asymetric_mutation(off1)
        }
        if (sample(c(1, 0), 1, prob = c(Mp, 1 - Mp)) == 1) {
            off2 <- asymetric_mutation(off2)
        }
        p <- 0.3 # Mutation for k (number of partitions)
        probs <- rep((1 - p) / 9, 9)
        k1 <- matingPool[Pair[1], "k"]
        k2 <- matingPool[Pair[2], "k"]
        probs[k1 - 1] <- probs[k1 - 1] + p / 2
        probs[k2 - 1] <- probs[k2 - 1] + p / 2
        offk1 <- sample(2:10, 1, prob = probs)
        offk2 <- sample(2:10, 1, prob = probs)
        # Add offsprings to new generation
        New[count, ] <- off1
        New[count + 1, ] <- off2
        NewK[, count] <- offk1
        NewK[, count + 1] <- offk2
    }
    return(list(New = New, NewK = NewK))
}

#' Title
#' Penalize Fitness2 function according the number of genes
#' @param x
#'
#' @return
#'
#' @examples
#' @noRd
penalize <- function(x) {
    1 / (1 + (x / 500)^2)
}


#' GSgalgoR main function
#'
#' \code{\link[GSgalgoR:galgo]{galgo}} accepts an expression matrix and a
#' survival object to find robust gene expression signatures related to a
#' given outcome
#'
#' @param population  a number indicating the number of solutions in the
#' population of solutions that will be evolved
#' @param generations a number indicating the number of iterations of the
#' galgo algorithm
#' @param nCV number of cross-validation sets
#' @param distancetype character, it can be
#' \code{'pearson'} (centered pearson), \code{'uncentered'}
#' (uncentered pearson), \code{'spearman'} or \code{'euclidean'}
#' @param TournamentSize a number indicating the size of the tournaments for
#' the selection procedure
#' @param period a number indicating the outcome period to evaluate the RMST
#' @param OS a \code{survival} object (see \code{ \link[survival]{Surv} }
#' function from the \code{\link{survival}} package)
#' @param prob_matrix a \code{matrix} or \code{data.frame}. Must be an
#' expression matrix with features in rows and samples in columns
#' @param res_dir a \code{character} string indicating where to save the
#' intermediate and final output of the algorithm
#' @param start_galgo_callback optional callback function for the start
#' of the galgo execution
#' @param end_galgo_callback optional callback function for the end of the
#' galgo execution
#' @param report_callback optional callback function
#' @param start_gen_callback optional callback function for the beginning
#' of the run
#' @param end_gen_callback optional callback function for the end of the run
#' @param verbose select the level of information printed during galgo
#' execution
#'
#' @return an object of type \code{'galgo.Obj'} that corresponds to a list
#' with the elements \code{$Solutions} and \code{$ParetoFront}.
#' \code{$Solutions} is a \eqn{l x (n + 5)} matrix where \eqn{n} is the number
#' of features evaluated and \eqn{l} is the number of solutions obtained.
#' The submatrix \eqn{l x n} is a binary matrix where each row represents
#' the chromosome of an evolved solution from the solution population, where
#' each feature can be present (1) or absent (0) in the solution.
#' Column \eqn{n +1} represent the  \eqn{k} number of clusters for each
#' solutions. Column \eqn{n+2} to \eqn{n+5} shows the SC Fitness and
#' Survival Fitness values, the solution rank, and the crowding distance of
#' the solution in the final pareto front respectively.
#' For easier interpretation of the \code{'galgo.Obj'}, the output can be
#' reshaped using the \code{\link[GSgalgoR:to_list]{to_list}} and
#' \code{\link[GSgalgoR:to_dataframe]{to_dataframe}} functions
#'
#' @export
#'
#' @usage galgo (population = 30, generations = 2, nCV = 5,
#' distancetype = "pearson", TournamentSize = 2, period = 1825,
#' OS, prob_matrix, res_dir = "", start_galgo_callback = callback_default,
#' end_galgo_callback = callback_base_return_pop,
#' report_callback = callback_base_report,
#' start_gen_callback = callback_default,
#' end_gen_callback = callback_default,
#' verbose = 2)
#'
#' @author Martin E Guerrero-Gimenez, \email{mguerrero@mendoza-conicet.gob.ar}
#'
#' @examples
#' # load example dataset
#' library(breastCancerTRANSBIG)
#' data(transbig)
#' Train <- transbig
#' rm(transbig)
#'
#' expression <- Biobase::exprs(Train)
#' clinical <- Biobase::pData(Train)
#' OS <- survival::Surv(time = clinical$t.rfs, event = clinical$e.rfs)
#'
#' # We will use a reduced dataset for the example
#' expression <- expression[sample(seq_len(nrow(expression)), 100), ]
#'
#' # Now we scale the expression matrix
#' expression <- t(scale(t(expression)))
#'
#' # Run galgo
#' output <- GSgalgoR::galgo(generations = 5, population = 15,
#' prob_matrix = expression, OS = OS)
#' outputDF <- to_dataframe(output)
#' outputList <- to_list(output)
galgo <- function(population = 30,# Number of individuals to evaluate
                generations = 2, # Number of generations
                nCV = 5,# Number of crossvalidations for function
                        # "crossvalidation"
                distancetype = "pearson",
                TournamentSize = 2,
                period = 1825,
                OS, # OS=Surv(time=clinical$time,event=clinical$status)
                prob_matrix,
                res_dir = "",
                start_galgo_callback = callback_default,
                end_galgo_callback = callback_base_return_pop,
                report_callback = callback_base_report,
                start_gen_callback = callback_default,
                end_gen_callback = callback_default,
                verbose = 2) {
    if (verbose == 0) {
        report_callback <- callback_default
        start_gen_callback <- callback_default
        end_gen_callback <- callback_default
    }

    if (verbose == 1) {
        report_callback <- callback_no_report
        start_gen_callback <- callback_default
        end_gen_callback <- callback_default
    }

    # Support for parallel computing.
    chk <- Sys.getenv("_R_CHECK_LIMIT_CORES_", "")
    if (nzchar(chk) && tolower(chk) == "true") {
        # use 2 cores in CRAN/Travis/AppVeyor
        num_workers <- 3L
    } else {
        # use all cores in devtools::test()
        num_workers <- parallel::detectCores()
    }
    cluster <-
        # convention to leave 1 core for OS
        parallel::makeCluster(num_workers - 1)
    doParallel::registerDoParallel(cluster)
    on.exit(parallel::stopCluster(cluster))
    on.exit()
    calculate_distance <- select_distance(distancetype)
    # Empty list to save the solutions.
    #PARETO <- list()
    PARETO <- vector("list",generations)
    chrom_length <- nrow(prob_matrix)
    # 1. Create random population of solutions.

    # Creating random clusters from 2-10.
    Nclust <- sample(2:10, population, replace = TRUE)

    # Matrix with random TRUE false with uniform distribution,
    # representing solutions to test.
    X <- matrix(NA, nrow = population, ncol = chrom_length)
    for (i in seq_len(population)) {
        prob <- stats::runif(1, 0, 1)
        X[i, ] <-
            sample(c(1, 0),
                chrom_length,
                replace = TRUE,
                prob = c(prob, 1 - prob)
            )
    }
    X1<-X
    start_galgo_callback(
        userdir = res_dir,
        generation = 0,
        pop_pool = X1,
        pareto = PARETO,
        prob_matrix = prob_matrix,
        current_time = start_time
    )

    ##### Main loop.
    end_OK <- TRUE
    for (g in seq_len(generations)) {
        # Output for the generation callback
        #callback_data <- list()
        #environment(start_gen_callback) <- environment()
        start_time <- Sys.time() # Measures generation time

        start_gen_callback(
            userdir = res_dir,
            generation = g,
            pop_pool = X1,
            pareto = PARETO,
            prob_matrix = prob_matrix,
            current_time = start_time
        )


        # 2.Calculate the fitness f(x) of each chromosome x in the population.
        # Apply constraints (min 10 genes per solution).
        # TODO: Check chrom_length parameter
        Fit1 <- apply(X, 1, mininum_genes, chrom_length = chrom_length)
        X <- X[Fit1, ]
        if (is.null(dim(X))){
            message("Galgo was unable to find a suitable solution. Consider 
                    using a bigger population.")
            end_OK <- FALSE
            break;
        }
        #message(Fit1)
        #message(dim(X))
        X <- apply(X, 2, as.logical)
        n <- nrow(X)
        Nclust <- Nclust[Fit1]

        k <- Nclust

        flds <- create_folds(seq_len(ncol(prob_matrix)), k = nCV)

        `%dopar%` <- foreach::`%dopar%`
        `%do%` <- foreach::`%do%`
        reqpkgs <-
            c("cluster", "proxy", "survival", "matchingR", "GSgalgoR")
        # reqpkgs <- c("cluster","cba", "survival", "matchingR")

        # Calculate Fitness 1 (silhouette) and 2 (Survival differences).
        Fit2 <- foreach::foreach(
            i = seq_len(nrow(X)),
            .packages = reqpkgs,
            .combine = rbind
        ) %dopar% {
            # devtools::load_all() # required for package devel
            crossvalidation(
                prob_matrix,
                flds,
                X[i, ],
                k[i],
                surv_obj = OS,
                distance = calculate_distance,
                nCV,
                period
            )
        }

        # Penalization of SC by number of genes.
        Fit2[, 1] <- (Fit2[, 1] * penalize(rowSums(X)))

        if (g == 1) {
            PARETO[[g]] <-
                Fit2    # Saves the fitness of the solutions of the
                        #current generation.
            # NonDominatedSorting from package nsga2R. -1
            # multiplication to alter the sign of the fitness
            # (function sorts from min to max).
            ranking <-
                nsga2R::fastNonDominatedSorting(Fit2 * -1)
            rnkIndex <- integer(n)
            i <- 1
            while (i <= length(ranking)) {
                # Save the rank of each solution.
                rnkIndex[ranking[[i]]] <- i
                i <- i + 1
            }
            # Data.frame with solution vector, number of clusters and ranking.
            X1 <-
                cbind(X, k, Fit2, rnkIndex)
            # Range of fitness of the solutions.
            objRange <-
                apply(Fit2, 2, max) - apply(Fit2, 2, min)
            # Crowding distance of each front (nsga2R package).
            CrowD <-
                nsga2R::crowdingDist4frnt(X1, ranking, objRange)
            CrowD <- apply(CrowD, 1, sum)
            # data.frame with solution vector, number of clusters,
            # ranking and crowding distance.

            X1 <-
                cbind(X1, CrowD)
            # Output for the generation callback
            report_callback(
                userdir = res_dir,
                generation = g,
                pop_pool = X1,
                pareto = PARETO,
                prob_matrix = prob_matrix,
                current_time =  Sys.time()
            )



            # Save parent generation.
            Xold <- X
            Nclustold <- Nclust

            # 3. create offspring.
            NEW <-
                offsprings(X1, chrom_length, population, TournamentSize)
            X <- NEW[["New"]]
            Nclust <- NEW[["NewK"]]
        } else {
            oldnew <- rbind(PARETO[[g - 1]], Fit2)
            oldnewfeature <- rbind(Xold, X)
            oldnewNclust <- c(Nclustold, Nclust)
            oldnewK <- oldnewNclust
            # NonDominatedSorting from package nsga2R. -1 multiplication to
            # alter the sign of the fitness (function sorts from min to max).
            rnkIndex2 <- integer(nrow(oldnew))
            ranking2 <-
                nsga2R::fastNonDominatedSorting(oldnew * -1)
            i <- 1
            while (i <= length(ranking2)) {
                # saves the rank of each solution.
                rnkIndex2[ranking2[[i]]] <- i
                i <- i + 1
            }

            X1 <-
                cbind(oldnewfeature,
                    k = oldnewK,
                    oldnew,
                    rnkIndex = rnkIndex2
                )
            # Range of fitness of the solutions.
            objRange <-
                apply(oldnew, 2, max) - apply(oldnew, 2, min)
            # Crowding distance of each front (nsga2R package).
            CrowD <-
                nsga2R::crowdingDist4frnt(X1, ranking2, objRange)
            CrowD <- apply(CrowD, 1, sum)
            # data.frame with solution vector, number of clusters,
            # ranking and crowding distance
            X1 <-
                cbind(X1, CrowD)
            X1 <- X1[X1[, "CrowD"] > 0, ]
            O <- order(X1[, "rnkIndex"],
                    X1[, "CrowD"] * -1)[seq_len(population)]
            X1 <- X1[O, ]
            # Saves the fitness of the solutions of the current generation
            PARETO[[g]] <-
                X1[, (chrom_length + 2):(chrom_length + 3)]
            # Output for the generation callback
            report_callback(
                userdir = res_dir,
                generation = g,
                pop_pool = X1,
                pareto = PARETO,
                prob_matrix = prob_matrix,
                current_time = Sys.time()
            )


            Xold <- X1[, seq_len(chrom_length)]
            Nclustold <- X1[, "k"]

            NEW <-
                offsprings(X1, chrom_length, population, TournamentSize)
            X <- NEW[["New"]]
            Nclust <- NEW[["NewK"]]
        }

        # 5.Go to step 2
        gc()

        end_gen_callback(
            userdir = res_dir,
            generation = g,
            pop_pool = X1,
            pareto = PARETO,
            prob_matrix = prob_matrix,
            current_time = Sys.time()
        )
    }

    parallel::stopCluster(cluster)
    if( end_OK == TRUE ){
        return (end_galgo_callback(
            userdir = res_dir,
            generation = g,
            pop_pool = X1,
            pareto = PARETO,
            prob_matrix = prob_matrix,
            current_time = Sys.time()
        ))
    }
}

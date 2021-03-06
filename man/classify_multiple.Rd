% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/results-functions.R
\name{classify_multiple}
\alias{classify_multiple}
\title{Classify samples from multiple centroids}
\usage{
classify_multiple(prob_matrix, centroid_list, distancetype = "pearson")
}
\arguments{
\item{prob_matrix}{a \code{matrix} or \code{data.frame}. Must be an
expression matrix with features in rows and samples in columns}

\item{centroid_list}{a\code{list} with the centroid matrix for each of
the signatures to evaluate, where each column represents the prototypic
centroid of a subtype and each row the constituents features of the
solution signature. The output of
\code{\link[GSgalgoR:create_centroids]{create_centroids}} can be used.}

\item{distancetype}{a \code{character} that can be either
\code{'pearson'} (default), \code{'spearman'} or \code{'kendall'}.}
}
\value{
Returns a \code{data.frame} with the classes assigned to
each sample in each signature, were samples are a rows and signatures
in columns
}
\description{
Classify samples from multiple centroids
}
\examples{
# load example dataset
library(breastCancerTRANSBIG)
data(transbig)
Train <- transbig
rm(transbig)

expression <- Biobase::exprs(Train)
clinical <- Biobase::pData(Train)
OS <- survival::Surv(time = clinical$t.rfs, event = clinical$e.rfs)

# We will use a reduced dataset for the example
expression <- expression[sample(1:nrow(expression), 100), ]

# Now we scale the expression matrix
expression <- t(scale(t(expression)))

# Run galgo
output <- GSgalgoR::galgo(generations = 5, population = 15,
prob_matrix = expression, OS = OS)
outputDF <- to_dataframe(output)
outputList <- to_list(output)

RESULTS <- non_dominated_summary(
    output = output, OS = OS,
    prob_matrix = expression,
    distancetype = "pearson"
)
CentroidsList <- create_centroids(output, RESULTS$solution,
trainset = expression)
classes <- classify_multiple(prob_matrix = expression,
centroid_list = CentroidsList)
}

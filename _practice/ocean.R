library(R6)
## Whales in the Ocean ----

Whale <- R6Class("Whale",
                 public = list(
                   position = NULL,
                   age = NULL,
                   lifespan = NULL,
                   range = NULL,
                   maturity = NULL,
                   stepSize = NULL,
                   initialize = function(position = NA, age = 3,
                                         lifespan = 40, range = 5,
                                         maturity = 10, stepSize = 5) {
                     self$position <- position
                     self$age <- age
                     self$lifespan <- lifespan
                     self$range <- range
                     self$maturity <- maturity
                     self$stepSize <- stepSize
                   }
                 ))

Whale$set("public",
          "move",
          function(dims, r = self$stepSize) {
            xMax <- dims[1]
            yMax <- dims[2]
            repeat {
              theta <- runif(1, min = 0, max = 2*pi)
              p <- self$position + r * c(cos(theta), sin(theta))
              within <- (p[1] > 0 && p[1] < xMax) && (p[2] > 0 && p[2] < yMax)
              if ( within ) {
                self$position <- p
                break
              }
            }
          }, overwrite = T)


Male <- R6Class("Male",
                inherit = Whale,
                public = list(
                  sex = "male"
                ))

Female <- R6Class("Female",
                inherit = Whale,
                public = list(
                  sex = "female",
                  timeToFertility = 0,
                  infertilityPeriod = 5
                ))

Female$set("public",
           "maleNear",
           function(males, dist) {
             foundOne <- FALSE
             for ( male in males ) {
               near <- dist(male$position, self$position) < self$range
               mature <- (male$age >= male$maturity)
               if ( near && mature ) {
                 foundOne <- TRUE
                 break
               }
             }
             foundOne
           }, overwrite = T)


Female$set("public",
           "mate",
           function() {
             babySex <- sample(c("female", "male"), size = 1)
             self$timeToFertility <- self$infertilityPeriod
             return(babySex)
           }, overwrite = T)

Ocean <- R6Class("Ocean",
                 public = list(
                   dimensions = NULL,
                   males = NULL,
                   females = NULL,
                   malePop = NULL,
                   femalePop = NULL,
                   starveParameter = NULL,
                   distance = function(a, b) {
                     sqrt((a[1] - b[1])^2 + (a[2] - b[2])^2)
                   },
                   initialize = function(dims = c(100, 100),
                                         males = 10,
                                         females = 10,
                                         starve = 5) {
                     self$dimensions <- dims
                     xMax <- dims[1]
                     yMax <- dims[2]
                     maleWhales <- replicate(males, 
                                             Male$new(age = 10, 
                                                      position = c(runif(1, 0, xMax),runif(1, 0, yMax))))
                     femaleWhales <- replicate(females, 
                                             Female$new(age = 10, 
                                                      position = c(runif(1, 0, xMax), runif(1, 0, yMax))))
                     self$males <- maleWhales
                     self$females <- femaleWhales
                     self$malePop <- males
                     self$femalePop <- females
                     self$starveParameter <- starve
                   },
                   starvationProbability = function(popDensity) {
                     self$starveParameter * popDensity
                   }
                 ))

Ocean$set("public",
          "advance",
          function() {
            malePop <- self$malePop
            femalePop <- self$femalePop
            population <- malePop + femalePop
            if ( population == 0 ) {
              return(NULL)
            }
            males <- self$males
            females <- self$females
            babyMales <- list()
            babyFemales <- list()
            if ( malePop > 0 && femalePop > 0 ) {
              for ( female in females ) {
                if ( female$timeToFertility <= 0 && female$maleNear(males = males,
                                                                    dist = self$distance)) {
                  outcome <- female$mate()
                  if ( outcome == "male" ) {
                    baby <- Male$new(age = 0, position = female$position)
                    babyMales <- c(babyMales, baby)
                  } else {
                    baby <- Female$new(age = 0, position = female$position)
                    babyFemales <- c(babyFemales, baby)
                  }
                }
              }
            }
            
            # augment the male and female lists if needed:
            lmb <- length(babyMales); lfb <- length(babyFemales);
            
            # throw in the babies:
            if ( lmb > 0 ) {
              males <- c(males, babyMales)
            }
            if ( lfb > 0 ) {
              females <- c(females, babyFemales)
            }
            
            # revise population for new births:
            population <- length(males) + length(females)
            
            # starve some of them, maybe:
            popDen <- population/prod(self$dimensions)
            starveProb <- self$starvationProbability(popDensity = popDen)
            maleDead <- logical(length(males))
            femaleDead <- logical(length(females))
            # starve some males
            for ( i in seq_along(maleDead) ) {
              male <- males[[i]]
              maleDead[i] <- (runif(1) <= starveProb)
              male$age <- male$age + 1
              if ( male$age >= male$lifespan ) maleDead[i] <- TRUE
              if ( maleDead[i] ) next
              # if whale is not dead, he should move:
              male$move(dims = self$dimensions)
            }
            # starve some females
            for ( i in seq_along(femaleDead) ) {
              female <- females[[i]]
              femaleDead[i] <- (runif(1) <= starveProb)
              female$age <- female$age + 1
              if ( female$age >= female$lifespan ) femaleDead[i] <- TRUE
              if ( femaleDead[i] ) next
              if ( female$sex == "female" ) {
                female$timeToFertility <- female$timeToFertility - 1
              }
              # if female is not dead, she should move:
              female$move(dims = self$dimensions)
            }
            
            # revise male and female whale lists:
            malePop <- sum(!maleDead)
            self$malePop <- malePop
            femalePop <- sum(!femaleDead)
            self$femalePop <- femalePop
            if ( malePop > 0 ) {
              self$males <- males[!maleDead]
            } else {
              self$males <- list()
            }
            if ( femalePop > 0 ) {
              self$females <- females[!femaleDead]
            } else {
              self$females <- list()
            }
          }, overwrite = T)

Ocean$set("public", 
          "plot",
          function() {
            males <- self$males[1:self$malePop]
            females <- self$females[1:self$femalePop]
            whales <- c(males, females)
            if ( length(whales) == 0) {
              plot(0,0, type = "n", main = "All Gone!")
              box(lwd = 2)
              return(NULL)
            }
            mat <- sapply(whales, function(x) {
              c(x$position[1], x$position[2],
                as.numeric(x$sex == "male"), as.numeric(x$age >= x$maturity))
              }, simplify = "array")
            mat <- simplify2array(t(mat))
            df <- as.data.frame(mat)
            names(df) <- c("x", "y", "sex", "mature")
            df$color <- ifelse(df$sex == 1, "red", "green")
            df$size <- ifelse(df$mature == 1, 1.3, 0.7)
            with(df, 
                 plot(x, y, xlim = c(0, self$dimensions[1]),
                 ylim = c(0, self$dimensions[1]), pch = 19, xlab = "",
                 ylab = "", axes = FALSE, col = color, cex = size,
                 main = paste0("Population = ", nrow(df))))
            box(lwd = 2)
          }, overwrite = T)


## programs ---------

oceanSim <- function(steps = 100, males = 10, females = 10) {
  ocean <- Ocean$new(dims = c(100, 100), males = males, females = females)
  population <-numeric(steps)
  for ( i in 1:steps ) {
    population[i] <- ocean$malePop + ocean$femalePop
    ocean$plot()
    if ( population[i] == 0 ) break
    ocean$advance()
    Sys.sleep(0.5)
  }
  pop <- population[1:i]
  plot(pop, type = "l")
}

oceanSim(steps = 200, males = 15, females = 15)


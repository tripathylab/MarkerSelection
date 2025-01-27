### this is reference code taken from https://github.com/PavlidisLab/neuroExpressoAnalysis/blob/master/R/rnaCoexist.R
### this is from Mancarci et al 2017

# remove plot output remnants

#' @export
rnaCoexist = function(rnaExp, # matrix of expressio values with row names = gene names
                      tresholds = NULL, # a data frame 1st col gene names 2nd col tresholds
                      genes, # list of genes
                      dupResolve=TRUE,
                      dataOut = NULL, # where to put the data
                      plotOut = NULL # where to plot shit
                      ,cores = 16){
    print('Im in')

    if(is.null(tresholds)){
        tresholds = data.frame(rownames(rnaExp), 1)
    }


    # browser()
    # returns the total score for a gene list
    countScore = function(geneList#,
                          #countThreshold
    ){
        #         relevant = presence[geneList,]
        #         relProbs = probs[names(probs) %in% geneList]
        #         relProbs = relProbs[match(rn(relevant), names(relProbs))]
        #         mean(apply(relevant,2,function(z){
        #             if (sum(z)>=max(len(z)*countThreshold,2)){
        #                 sum(z/relProbs)
        #             } else{
        #                 0
        #             }
        #         })
        #         )
        matrix = presence[geneList,]
        cor(matrix %>% t) %>% sm2vec # %>% median
        #         geneProbs = apply(matrix,1, function(x){sum(x)/len(x)})
        #         cellP = apply(matrix,2,function(x){
        #             isThere = (geneProbs[x])
        #             isThere %>% log %>% sum %>% exp
        #             #grid = teval(paste0('expand.grid(',paste(rep('c(T,F)',sum(!x)),collapse=', '),')'))
        #             #probMat = cbind(repRow(isThere,nrow(grid)),repRow(geneProbs[!x],nrow(grid)) * grid +
        #             #                    (1-repRow(geneProbs[!x],nrow(grid))) * !grid)
        #             # log(probMat) %>% apply(1,sum) %>% exp %>% sum
        #         })
        #         log(cellP) %>% boxplot.stats %$% out %>% len

    }

    print('i did something')
    presence = t(sapply(1:nrow(rnaExp),function(x){
        rnaExp[x,]>=tresholds[x,2]
    }))
    print('presence matrix generated')
    rownames(presence) = rownames(rnaExp)
    probs = apply(presence,1, function(x){sum(x)})
    probs = probs[probs > 0]
    probs = sort(probs)

    # limit what you are looking with genes that are in the dataset somewhere
    genesInSeq = lapply(genes, function(x){
        x[x %in% names(probs)]
    })

    realProbs = sapply(genesInSeq, countScore#,
                       #countThreshold
    )
    print('gene prevelance calculated')



    # simulate coexistance prevelance ------------------

    selectRandom = function(gene,n, invalids = c()){
        #print(gene)
        #browser()
        probs = probs[!names(probs) %in% invalids]
        prob = probs[gene]
        geneProp = ecdf(probs)(probs[gene])
        # max value cant be 1 since the resulting vector does not have a standard deviation
        range = quantile(probs, c(max(geneProp-.025,0), min(geneProp+.025,0.99)))
        eligible = which(probs>=range[1] & probs <= range[2])
        # loc = which(names(probs) == gene)
        # eligible = (loc-500):(loc+500)
        # eligible = which((probs < prob + prob*0.2) & (probs > prob - prob*0.2))
        selection = names(probs[sample(eligible,n,replace=T)])
        return(selection)
    }

    print('parallel shit')
    #browser()
    #for (x in 5) {
    simuProbs =
        mclapply(1:len(genesInSeq),function(x){
            print(x)
            if (len(genesInSeq[[x]])<2){
                return(NA)
            }

            simuGenes = sapply(genesInSeq[[x]], selectRandom, 500)
            print('random genes selected')
            # make sure there are no dupes
            if (dupResolve==T){
                while (any(apply(apply(simuGenes,1,duplicated),2,any))){
                    print(paste("had to resolve equality",names(genesInSeq)[x],' in ',
                                sum(apply(apply(simuGenes,1,duplicated),2,any))))
                    simuGenes[apply(apply(simuGenes,1,duplicated),2,any),] =
                        t( apply(simuGenes[apply(apply(simuGenes,1,duplicated),2,any),,drop=F],1, function(x){
                            x = sample(x,len(x), replace = F)
                            x[duplicated(x)] = sapply(1:sum(duplicated(x)), function(y){
                                selectRandom(x[duplicated(x)][y],n=1,invalids=x[!x %in% x[duplicated(x)][y]])
                            })
                            return(x)
                        }))
                }
            }

            a = apply(simuGenes,1,countScore#,countThreshold
            )
            print('rereroro')
            return(a)
        } , mc.cores=cores
        )
    names(simuProbs) = names(genesInSeq)
    print('fake gene correlations calculated')
    # p value calculation
    #     ps = sapply(1:len(realProbs), function(i){
    #         if (all(simuProbs[[i]] == realProbs[i])){
    #             return(NA)
    #         }
    #         1-ecdf(simuProbs[[i]])(realProbs[i])
    #     })

    #print('i'm debugging)
    ps = sapply(1:len(simuProbs), function(j){
        print('dunnit')
        #browser()
        wilcox.test(simuProbs[[j]] %>% as.vector, realProbs[[j]], alternative = 'less')$p.value
    })


    ps = p.adjust(ps, method='fdr')
    print('p values done')
    if(!is.null(dataOut)){
        dir.create(dataOut, recursive = T, showWarnings=F)
        names(ps) = names(realProbs)
        toWrite = data.frame(ps,
                             meanCor = realProbs %>%sapply(mean),
                             geneCount = genesInSeq %>% sapply(len))
        write.table(toWrite,
                    paste0(dataOut, '/','realProbs'),quote=FALSE, sep = '\t')
        #write.table(as.data.frame(simuProbs),
        #            paste0(dataOut,'/','simuProbs'), quote=F, row.names=F)
        for (i in 1:len(genes)){
            toWrite = (matrix(as.numeric(presence[rownames(presence) %in% genes[[i]],]),ncol=ncol(presence)))
            if (nrow(toWrite)<=1){
                next
            }
            rownames(toWrite) = rownames(presence)[rownames(presence) %in% genes[[i]]]
            write.table(toWrite,
                        paste0(dataOut,'/',names(genes)[i]))
        }

    }
    print('yay tables')
    if (!is.null(plotOut)){
        dir.create(plotOut, recursive = T, showWarnings=F)

        # heatmaps of existance --------------

        for (i in 1:len(genes)){
            toPlot = (matrix(as.numeric(presence[rownames(presence) %in% genes[[i]],]),ncol=ncol(presence)))
            if (nrow(toPlot)<=1){
                next
            }
            rownames(toPlot) = rownames(presence)[rownames(presence) %in% genes[[i]]]
            png(paste0(plotOut,'/', names(genes)[i],'_heat.png'), height = 800, width= 800)
            tryCatch({
                heatmap.2(t(toPlot),trace= 'none', Rowv=T, Colv=T,dendrogram='column',main = names(genes)[i], col = c('white',muted('blue')))
            }, error = function(e){
                tryCatch({heatmap.2(t(toPlot),trace= 'none', Rowv=T, Colv=F,dendrogram='none',main = names(genes)[i], col = c('white',muted('blue')))},
                         error = function(e){
                             heatmap.2(t(toPlot),trace= 'none', Rowv=F, Colv=F,dendrogram='none',main = names(genes)[i], col = c('white',muted('blue')))
                         })
            })
            dev.off()
        }
        # heatmap of coexpression
        for (i in 1:len(genes)){
            toPlot = (matrix(as.numeric(presence[rownames(presence) %in% genes[[i]],]),ncol=ncol(presence)))
            if (nrow(toPlot)<=1){
                next
            }
            rownames(toPlot) = rownames(presence)[rownames(presence) %in% genes[[i]]]
            toPlot %<>% t %>% cor
            png(paste0(plotOut,'/', names(genes)[i],'_corr_heat.png'), height = 800, width= 800)
            tryCatch({
                heatmap.2((toPlot),trace= 'none', Rowv=T, Colv=T,dendrogram='column',main = names(genes)[i], col = colorRampPalette(c('white',muted('blue')))(10))
            }, error = function(e){
                tryCatch({heatmap.2((toPlot),trace= 'none', Rowv=T, Colv=F,dendrogram='none',main = names(genes)[i], col = colorRampPalette(c('white',muted('blue')))(10))},
                         error = function(e){
                             heatmap.2((toPlot),trace= 'none', Rowv=F, Colv=F,dendrogram='none',main = names(genes)[i], col = colorRampPalette(c('white',muted('blue')))(10))
                         })
            })
            dev.off()
        }
        print('yay heatmaps')
    }
    print('yay output')
    #invisible(list(data.frame(realProbs,ps), as.data.frame(simuProbs)))
}

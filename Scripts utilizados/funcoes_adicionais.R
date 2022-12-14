### Funções adicionais para o uso de ambos os scripts de processamento com xcms/CAMERA
###
### Autora: Anna Clara de Freitas Couto, 2022.
###
### Requisitos: 
###   R
###   xcms (pacote)
###   CAMERA (pacote)
###   CluMSID (pacote)
###   metaMS (pacote)
###


###
###   Função adaptada do pacote CluMSID para construir espectros em formato específico, a partir de dados de deconvolução
###   do pacote CAMERA. Utiliza 5 como valor mínimo de picos para que o espectros seja considerado viável
###

extract_spectra <- function(x) {
  if (is(x, "xsAnnotate")) {
    if (sum(grepl("X", colnames(x@groupInfo)) == TRUE) == 0) { # for database, theres is no sample column in x@groupInfo
      sv <- which(colnames(x@groupInfo) == "into")
    } else { # procura por colunas in x@groupInfo correspondentes à cada amostra to each sample
      temp <- list()
      for (j in seq_along(rownames(x@xcmsSet@phenoData))) {
        temp[[j]] <- grep(
          paste0("^X", rownames(x@xcmsSet@phenoData)[j], "$"),
          colnames(x@groupInfo)
        )
      }
      sv <- unique(unlist(temp))
    }

    # remove NAs
    x@groupInfo[, sv][is.na(x@groupInfo[, sv])] <- 0

    pseudospeclist <- list()
    for (i in seq_along(x@pspectra)) {
      if (length(x@pspectra[[i]]) > 1) {    # checagem da estrutura dos dados
        if (sum(grepl("X", colnames(x@groupInfo)) == TRUE) == 0) {
          spc <- cbind(x@groupInfo[x@pspectra[[i]], "mz"], x@groupInfo[x@pspectra[[i]], sv])
        } else {
          spc <- cbind(x@groupInfo[x@pspectra[[i]], "mz"], rowMax(x@groupInfo[x@pspectra[[i]], sv]))
        }
        if (sum(is.na(spc)) >= 1) {
          spc <- spc[-(which(is.na(spc), arr.ind = TRUE)[, 1]), ]
        }
      } else {
        spc <- cbind(
          x@groupInfo[x@pspectra[[i]], "mz"],
          max(x@groupInfo[x@pspectra[[i]], sv],
            na.rm = TRUE
          )
        )
      }
      pseudospeclist[[i]] <- new("pseudospectrum",
        id = i,
        rt =
          median(
            x@groupInfo[
              x@
              pspectra[[i]],
              "rt"
            ]
          ),
        spectrum = spc
      )
    }
  }
  ## Filtrar espectros com número mínimo de picos
  psvec <- c()
  for (i in seq_along(pseudospeclist)) {
    psvec[i] <- nrow(pseudospeclist[[i]]@spectrum) > 5
  }
  return(pseudospeclist[psvec])
}



## create_spectra is a function to format the spectra data into a acceptable format to be written into .msp file by metaMS functions.
# pslist is a list of spectra generated by extract_spectra


###
###   Função para adaptação dos dados gerados pelo processamento e criação do arquivo de espectros de massas '.msp'
###   para ser utilizado no software NIST MS Search.
###
create_spectra <- function (pslist) {
    ## adapta os dados para criar o arquivo '.msp' de espectro
    spectra <- list()
    for (i in 1:length(pslist)) {
        x <- data.frame(cbind(pslist[[i]]@spectrum[, 1], (pslist[[i]]@spectrum[, 2] / max(pslist[[i]]@spectrum[, 2])))) # standardazing intensities by dividing the intensity of each peak from a spectrum by the maximum intensity of that spectra.
        colnames(x) <- c("mz", "into")
        spectra[[i]] <- x
    }
    result <- metaMS::construct.msp(spectra, extra.info = NULL)
    for (i in 1:length(result)) {
        result[[i]]$id <- pslist[[i]]@id
        result[[i]]$rt <- pslist[[i]]@rt
        result[[i]]$Name <- paste0("Unknown ", pslist[[i]]@id)
        result[[i]]$Date <- as.character(Sys.Date())
    }
    metaMS::write.msp(result, "spectra.msp", newFile = TRUE)
}

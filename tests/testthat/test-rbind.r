context("rbind")

df_var <- data.frame(
  l = c(T, F, F),
  i = c(1, 1, 2),
  d = Sys.Date() + c(1, 1, 2),
  f = factor(letters[c(1, 1, 2)]),
  n = c(1, 1, 2) + 0.5,
  t = Sys.time() + c(1, 1, 2),
  c = letters[c(1, 1, 2)],
  stringsAsFactors = FALSE
)

test_that("rbind_list works on key types", {
  exp <- tbl_df( rbind( df_var, df_var, df_var ) )
  expect_equal(
    rbind_list( df_var, df_var, df_var) ,
    exp
  )
})

test_that("rbind_list reorders columns", {
  columns <- seq_len(ncol(df_var))
  exp <- tbl_df( rbind( df_var, df_var, df_var ) )
  expect_equal(
    rbind_list(
      df_var,
      df_var[, sample(columns)],
      df_var[, sample(columns)]
    ),
    exp
  )
})

test_that("rbind_list promotes integer to numeric", {
  df  <- data.frame( a = 1:5, b = 1:5 )
  df2 <- df
  df2$a <- as.numeric(df$a)

  res <- rbind_list( df, df2)
  expect_equal( typeof(res$a), "double" )
  expect_equal( typeof(res$b), "integer" )
})

test_that("rbind_list promotes factor to character", {
  df  <- data.frame( a = letters[1:5], b = 1:5, stringsAsFactors=TRUE )
  df2 <- df
  df2$a <- as.character(df$a)

  res <- rbind_list( df, df2)
  expect_equal( typeof(res$a), "character" )
})

test_that("rbind_list doesn't promote factor to numeric", {
  df1 <- data.frame( a = 1:5, b = 1:5 )
  df2 <- data.frame( a = 1:5, b = factor(letters[1:5]) )

  expect_error(rbind_list( df1, df2 ), "incompatible type")
})

test_that("rbind_list doesn't coerce integer to factor", {
  df1 <- data.frame( a = 1:10, b = 1:10 )
  df2 <- data.frame( a = 1:5, b = factor(letters[1:5]) )

  expect_error( rbind_list( df1, df2 ), "incompatible type" )
})

test_that( "rbind_list coerces factor to character when levels don't match", {
  df1 <- data.frame( a = 1:3, b = factor(c("a", "b", "c")))
  df2 <- data.frame( a = 1:3, b = factor(c("a", "b", "c"),
      levels = c("b", "c", "a", "d")))

  expect_warning(res <- rbind_list( df1, df2 ),
    "Unequal factor levels: coercing to character")
  expect_equal( res$b, c("a","b","c", "a","b","c" ) )
})

test_that( "rbind handles NULL",{
  x <- cbind(a=1:10,b=1:10)
  y <- data.frame(x)
  res <- rbind_all(list(y,y,NULL,y))
  expect_equal(nrow(res), 30L)
})

test_that( "rbind handles NA in factors #279", {
  xx <- as.data.frame(list(a=as.numeric(NA), b="c", c="d"))
  zz <- as.data.frame(list(a=1, b=as.character(NA), c="b"))
  expect_warning( res <- rbind_list( xx, zz ) )

  expect_equal(res$a, c(NA,1.0))
  expect_equal(res$b, c("c", NA))
  expect_equal(res$c, c("d","b"))

})

test_that( "rbind_all only accepts data frames #288",{
  ll <- list(c(1,2,3,4, 5), c(6, 7, 8, 9, 10))
  expect_error(rbind_all(ll))
})

test_that( "rbind propagates timezone for POSIXct #298", {
  dates1 <- data.frame(ID=c("a", "b", "c"),
                     dates=structure(c(-247320000, -246196800, -245073600),
                                     tzone = "GMT",
                                     class = c("POSIXct", "POSIXt")),
                     stringsAsFactors=FALSE)

  dates2 <- data.frame(ID=c("d", "e", "f"),
                       dates=structure(c(-243864000, -242654400, -241444800),
                                       tzone = "GMT",
                                       class = c("POSIXct", "POSIXt")),
                       stringsAsFactors=FALSE)

  alldates <- rbind_list(dates1, dates2)
  expect_equal( attr( alldates$dates, "tzone" ), "GMT" )
})

test_that( "Collecter_Impl<REALSXP> can collect INTSXP. #321", {
  res <- rbind_list(data.frame(x=0.5), data.frame(x=1:3))
  expect_equal( res$x, c(0.5, 1:3) )
})

test_that( "Collecter_Impl<INTSXP> can collect LGLSXP. #321", {
  res <-  rbind_list(data.frame(x=1:3), data.frame(x=NA))
  expect_equal( res$x, c(1:3, NA) )
})

test_that("rbind_all handles list columns (#463)", {
  dfl <- data.frame(x = I(list(1:2, 1:3, 1:4)))
  res <- rbind_all(list(dfl, dfl))
  expect_equal(rep(dfl$x,2L), res$x)
})

test_that("rbind_all creates tbl_df object", {
  res <- rbind_list(tbl_df(mtcars))
  expect_is( res, "tbl_df" )
})

test_that("string vectors are filled with NA not blanks before collection (#595)", {
  one <- mtcars[1:10, -10]
  two <- mtcars[11:32, ]
  two$char_col <- letters[1:22]

  res <- rbind_list(one, two)
  expect_true( all(is.na(res$char_col[1:10])) )
})

test_that("rbind handles data frames with no rows (#597)",{
  empty <- data.frame(result = numeric())
  expect_equal(rbind_list(empty), tbl_df(empty))
  expect_equal(rbind_list(empty, empty), tbl_df(empty))
  expect_equal(rbind_list(empty, empty, empty), tbl_df(empty))
})

test_that("rbind handles all NA columns (#493)", {
  mydata <- list(
    data.frame(x=c("foo", "bar")),
    data.frame(x=NA)
  )
  res <- rbind_all(mydata)
  expect_true( is.na(res$x[3]) )
  expect_is( res$x, "factor" )

  mydata <- list(
    data.frame(x=NA),
    data.frame(x=c("foo", "bar"))
  )
  res <- rbind_all(mydata)
  expect_true( is.na(res$x[1]) )
  expect_is( res$x, "factor" )

})

test_that( "bind_rows handles complex. #933", {
  df1 <- data.frame(r = c(1+1i, 2-1i))
  df2 <- data.frame(r = c(1-1i, 2+1i))
  df3 <- bind_rows(df1,df2)
  expect_equal( nrow(df3), 4L)
  expect_equal( df3$r, c(df1$r, df2$r) )
})

test_that("bind_rows is careful about column names encoding #1265", {
  one <- data.frame(fü=1:3, bar=1:3)
  two <- data.frame(fü=1:3, bar=1:3)
  Encoding(names(one)[1]) <- "UTF-8"
  expect_equal( names(one), names(two))
  res <- bind_rows(one,two)
  expect_equal(ncol(res), 2L)
})

test_that("bind_rows handles POSIXct (#1125)", {
  df1 <- data.frame(date = as.POSIXct(NA))
  df2 <- data.frame(date = as.POSIXct("2015-05-05"))
  res <- bind_rows(df1,df2)
  expect_equal(nrow(res),2L)
  expect_true(is.na(res$date[1]))
})

test_that("bind_rows respects ordered factors (#1112)", {
  l <- c("a", "b", "c", "d")
  id <- factor(c("a", "c", "d"), levels = l, ordered = TRUE)
  df <- data.frame(id = rep(id, 2), val = rnorm(6))
  res <- bind_rows(df, df)
  expect_is( res$id, "ordered")
  expect_equal( levels(df$id), levels(res$id) )

  res <- group_by(df, id) %>% do(na.omit(.))
  expect_is( res$id, "ordered")
  expect_equal( levels(df$id), levels(res$id) )
})

test_that("bind_rows can handle lists (#1104)", {
  my_list <- list(list(x = 1, y = 'a'), list(x = 2, y = 'b'))
  res <- bind_rows(my_list)
  expect_equal(nrow(res), 2L)
  expect_is(res$x, "numeric")
  expect_is(res$y, "character")

  res <- bind_rows(list(x = 1, y = 'a'), list(x = 2, y = 'b'))
  expect_equal(nrow(res), 2L)
  expect_is(res$x, "numeric")
  expect_is(res$y, "character")
})

test_that("bind handles POSIXct of different tz ", {
  date1 <- structure(-1735660800, tzone = "America/Chicago", class = c("POSIXct", "POSIXt"))
  date2 <- structure(-1735660800, tzone = "UTC", class = c("POSIXct", "POSIXt"))
  date3 <- structure(-1735660800, class = c("POSIXct", "POSIXt"))

  df1 <- data.frame( date = date1 )
  df2 <- data.frame( date = date2 )
  df3 <- data.frame( date = date3 )

  res <- bind_rows(df1, df2)
  expect_equal( attr(res$date, "tzone"), "UTC" )

  res <- bind_rows(df1, df3)
  expect_equal( attr(res$date, "tzone"), "America/Chicago" )

  res <- bind_rows(df2, df3)
  expect_equal( attr(res$date, "tzone"), "UTC" )

  res <- bind_rows(df3, df3)
  expect_equal( attr(res$date, "tzone"), NULL )

  res <- bind_rows(df1, df2, df3)
  expect_equal( attr(res$date, "tzone"), "UTC" )

})

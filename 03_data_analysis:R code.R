#加载必要的包
library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(tidyr)
library(ggplot2)
library(psych) 

########################## H1 检验 #############################################
#先用python做新闻网站数据中日期列的转换
#Step 1：读取【新闻网站】全年数据（已清洗日期）
news_raw <- read_excel(
  "C:/Users/97201/Desktop/6601 R code/新闻网站数据（总）_date_cleaned.xlsx"
)

#检查关键列
colnames(news_raw)

#构建「新闻每日议程」
news_daily <- news_raw %>%
  filter(!is.na(date_clean)) %>%
  group_by(date_clean) %>%
  summarise(
    news_count = n(),
    .groups = "drop"
  ) %>%
  arrange(date_clean)

#快速检查
summary(news_daily$news_count)
nrow(news_daily)
head(news_daily)
describe(news_daily)
column_sum <- sum(news_daily$news_count)
print(column_sum)

#Step 2：读取 & 合并【微博】全年数据
#列出 12 个月文件夹
weibo_base_path <- "C:/Users/97201/Desktop/6601 R code/微博清洗后数据"

month_dirs <- list.dirs(
  weibo_base_path,
  recursive = FALSE
)

month_dirs

#读取每月数据
install.packages("janitor")
library(janitor)

read_weibo_month <- function(month_path) {
  
  files <- list.files(
    month_path,
    pattern = "\\.xlsx$",
    full.names = TRUE
  )
  
  # ❗排除 Excel 临时锁定文件
  files <- files[!grepl("^~\\$", basename(files))]
  
  map_df(files, function(f) {
    
    df <- read_excel(f, col_types = "text") %>%
      clean_names()
    
    # 互动列补齐
    if (!"like_count" %in% colnames(df)) df$like_count <- NA
    if (!"repost_count" %in% colnames(df)) df$repost_count <- NA
    if (!"comment_count" %in% colnames(df)) df$comment_count <- NA
    
    df %>%
      mutate(
        like_count = as.numeric(like_count),
        repost_count = as.numeric(repost_count),
        comment_count = as.numeric(comment_count),
        source_file = f
      )
  })
}


weibo_raw <- map_df(month_dirs, read_weibo_month)

#查看数据总和
nrow(weibo_raw)

#构建微博的日议程（weibo_daily）
colnames(weibo_raw)

install.packages("lubridate") 
library(lubridate)

#侦查数据形式
weibo_raw %>%
  select(publish_time) %>%
  slice_sample(n = 20)

weibo_daily <- weibo_raw %>%
  mutate(
    publish_time = as.character(publish_time),
    
    datetime = case_when(
      
      # ① 含年份：2025-01-01 / 2025/01/01
      grepl("^\\d{4}[-/]", publish_time) ~ as.POSIXct(
        publish_time,
        format = "%Y-%m-%d %H:%M:%S",
        tz = "Asia/Shanghai"
      ),
      
      # ② 不含年份：01月01日 00:05
      grepl("月", publish_time) ~ as.POSIXct(
        paste0("2025年", publish_time),
        format = "%Y年%m月%d日 %H:%M",
        tz = "Asia/Shanghai"
      ),
      
      TRUE ~ NA
    ),
    
    date = as.Date(datetime)
  ) %>%
  filter(!is.na(date)) %>%
  count(date, name = "weibo_count") %>%
  arrange(date)

range(weibo_daily$date)
nrow(weibo_daily)
summary(weibo_daily$weibo_count)

#合并新闻议程和微博议程
news_daily <- news_raw %>%
  mutate(date = as.Date(date_clean)) %>%   # 👈 统一叫 date
  count(date, name = "news_count") %>%
  arrange(date)


agenda_daily <- full_join(
  news_daily,
  weibo_daily,
  by = "date"
) %>%
  replace_na(list(news_count = 0, weibo_count = 0)) %>%
  arrange(date)

agenda_daily <- agenda_daily %>%
  filter(date >= as.Date("2025-01-01"),
         date <= as.Date("2025-12-31"))

range(agenda_daily$date)
nrow(agenda_daily)

#描述性统计
summary(agenda_daily$news_count)
summary(agenda_daily$weibo_count)

describe(agenda_daily)

# Pearson 相关
cor_test_h1 <- cor.test(
  agenda_daily$news_count,
  agenda_daily$weibo_count,
  method = "pearson"
)

cor_test_h1

# 时间滞后分析（news → weibo）
agenda_daily <- agenda_daily %>%
  arrange(date) %>%
  mutate(
    news_lag1 = lag(news_count, 1),
    news_lag2 = lag(news_count, 2),
    news_lag3 = lag(news_count, 3)
  )

cor.test(agenda_daily$news_lag1, agenda_daily$weibo_count, use = "complete.obs")
cor.test(agenda_daily$news_lag2, agenda_daily$weibo_count, use = "complete.obs")
cor.test(agenda_daily$news_lag3, agenda_daily$weibo_count, use = "complete.obs")

#回归模型
#（1）当天效应（baseline）
model_0 <- lm(
  weibo_count ~ news_count,
  data = agenda_daily
)
summary(model_0)

#（2）延后1天
model_1 <- lm(
  weibo_count ~ news_lag1,
  data = agenda_daily
)
summary(model_1)

#（3）延后2天
model_2 <- lm(
  weibo_count ~ news_lag2,
  data = agenda_daily
)
summary(model_2)

# （4）延后3天
model_3 <- lm(
  weibo_count ~ news_lag3,
  data = agenda_daily
)
summary(model_3)

#H1结果可视化
library(broom)
library(ggplot2)

models <- list(
  lag0 = model_0,
  lag1 = model_1,
  lag2 = model_2,
  lag3 = model_3
)

coef_df <- purrr::map_df(
  models,
  ~ tidy(.x),
  .id = "lag"
) %>%
  filter(term != "(Intercept)")

ggplot(coef_df, aes(x = lag, y = estimate)) +
  geom_point(size = 3) +
  geom_line(group = 1) +
  geom_errorbar(
    aes(ymin = estimate - 1.96 * std.error,
        ymax = estimate + 1.96 * std.error),
    width = 0.1
  ) +
  labs(
    x = "Lag of News Count",
    y = "Regression Coefficient (β)",
    title = "Lagged Effects of News Agenda on Weibo Agenda"
  ) +
  theme_minimal()

#model 2 回归拟合图
ggplot(agenda_daily, aes(x = news_lag2, y = weibo_count)) +
  geom_point(alpha = 0.3) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    x = "News Count (Lag 2)",
    y = "Weibo Count",
    title = "Lag-2 Effect of News Agenda on Weibo Agenda"
  ) +
  theme_minimal()

#model 3 回归拟合图
ggplot(agenda_daily, aes(x = news_lag3, y = weibo_count)) +
  geom_point(alpha = 0.3) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    x = "News Count (Lag 3)",
    y = "Weibo Count",
    title = "Lag-3 Effect of News Agenda on Weibo Agenda"
  ) +
  theme_minimal()

#######################H2 检验#################################################
#Step1: 统一 Attribute（框架）分类
attribute_map <- data.frame(
  keyword = c(
    # Attribute A: Structural / Institutional
    "加班", "996", "劳动法", "加班费",
    "职场内卷", "职场竞争", "职场PUA", "职场霸凌",
    
    # Attribute B: Psychological & Health Consequences
    "工作压力", "职场焦虑", "职场压力", "工作焦虑",
    "工作倦怠", "工作过劳", "工作疲惫", "职业倦怠", "工作躺平",
    
    # Attribute C: Organizational Responsibility & Support
    "企业责任", "员工关怀", "职业健康",
    "职场心理咨询", "职场心理健康", "职场关怀"
  ),
  attribute = c(
    rep("Structural", 8),
    rep("Health", 9),
    rep("Organizational Responsibility", 6)
  ),
  stringsAsFactors = FALSE
)

#Step 2:新闻数据：构建「属性 × 日期」议程
#给新闻数据加 Attribute 标签
news_attr <- news_raw %>%
  left_join(attribute_map, by = c('Key Word'= "keyword")) %>%
  filter(!is.na(attribute))

#聚合为「每日 × 属性」新闻议程
news_attr_daily <- news_attr %>%
  group_by(date_clean, attribute) %>%
  summarise(news_count = n(), .groups = "drop") %>%
  rename(date = date_clean)

#Step 3:微博数据：构建「属性 × 日期 × 公众参与」
#给微博加 Attribute 标签
weibo_attr <- weibo_raw %>%
  left_join(attribute_map, by = c("key_word" = "keyword")) %>%
  filter(!is.na(attribute))

#构建「公众参与度」指标
weibo_attr <- weibo_attr %>%
  mutate(
    engagement = `like_count` + `repost_count` + `comment_count`
  )

#聚合为「每日 × 属性」微博参与议程
weibo_attr <- weibo_attr %>%
  mutate(
    date_string = paste0(
      "2025-",
      stringr::str_extract(publish_time, "\\d{1,2}"),
      "-",
      stringr::str_extract(publish_time, "(?<=月)\\d{1,2}")
    ),
    date = as.Date(date_string)
  )

weibo_attr_daily <- weibo_attr %>%
  group_by(date, attribute) %>%
  summarise(
    engagement_sum = sum(engagement, na.rm = TRUE),
    .groups = "drop"
  )

agenda_attr_daily <- full_join(
  news_attr_daily,
  weibo_attr_daily,
  by = c("date", "attribute")
)

#处理缺失值
agenda_attr_daily <- agenda_attr_daily %>%
  mutate(
    news_count = ifelse(is.na(news_count), 0, news_count),
    engagement_sum = ifelse(is.na(engagement_sum), 0, engagement_sum),
    log_engagement = log(engagement_sum + 1)
  )

#按属性生成 lag1
agenda_attr_daily <- agenda_attr_daily %>%
  arrange(attribute, date) %>%
  group_by(attribute) %>%
  mutate(
    news_lag1 = lag(news_count, 1)
  ) %>%
  ungroup()

#Step 4：描述性统计
#每天的整体分布
library(dplyr)
library(psych)

H2_daily_overall <- agenda_attr_daily %>%
  group_by(date) %>%
  summarise(
    total_posts = sum(news_count, na.rm = TRUE),
    total_engagement = sum(engagement_sum, na.rm = TRUE)
  )

describe(H2_daily_overall[, c("total_posts", "total_engagement")])

#各框架的日均发帖量 & 互动量
H2_attribute_desc <- agenda_attr_daily %>%
  group_by(attribute) %>%
  summarise(
    days = n(),
    mean_posts = mean(news_count, na.rm = TRUE),
    sd_posts = sd(news_count, na.rm = TRUE),
    min_posts = min(news_count, na.rm = TRUE),
    max_posts = max(news_count, na.rm = TRUE),
    
    mean_engagement = mean(engagement_sum, na.rm = TRUE),
    sd_engagement = sd(engagement_sum, na.rm = TRUE),
    min_engagement = min(engagement_sum, na.rm = TRUE),
    max_engagement = max(engagement_sum, na.rm = TRUE)
  )

H2_attribute_desc

#各框架在一年内的总量占比
H2_attribute_share <- agenda_attr_daily %>%
  group_by(attribute) %>%
  summarise(
    total_posts = sum(news_count, na.rm = TRUE),
    total_engagement = sum(engagement_sum, na.rm = TRUE)
  ) %>%
  mutate(
    post_share = total_posts / sum(total_posts),
    engagement_share = total_engagement / sum(total_engagement)
  )

H2_attribute_share

#检查是否有大量的0
agenda_attr_daily %>%
  group_by(attribute) %>%
  summarise(
    zero_days = sum(news_count == 0),
    total_days = n(),
    zero_ratio = zero_days / total_days
  )

#Step 5：Pearson 分析
H2_lag0 <- agenda_attr_daily %>%
  group_by(attribute) %>%
  summarise(
    cor = cor(news_count, log_engagement, use = "complete.obs"),
    p_value = cor.test(news_count, log_engagement)$p.value,
    n = sum(!is.na(news_count) & !is.na(log_engagement)),
    .groups = "drop"
  )

H2_lag1 <- agenda_attr_daily %>%
  group_by(attribute) %>%
  summarise(
    cor = cor(news_lag1, log_engagement, use = "complete.obs"),
    p_value = cor.test(news_lag1, log_engagement)$p.value,
    n = sum(!is.na(news_lag1) & !is.na(log_engagement)),
    .groups = "drop"
  )

#查看结果
H2_lag0
H2_lag1

#Step 6：回归分析
#变量变换，对 engagement 做 log 变换
agenda_attr_daily <- agenda_attr_daily %>%
  mutate(
    log_engagement = log1p(engagement_sum)  # log(engagement + 1)
  )

#为 H2 构建 lag1 自变量
agenda_attr_daily <- agenda_attr_daily %>%
  arrange(attribute, date) %>%
  group_by(attribute) %>%
  mutate(
    news_lag1 = lag(news_count, 1)
  ) %>%
  ungroup()

#模型 1：当天效应（baseline）
model_H2_0 <- lm(
  log_engagement ~ news_count + attribute,
  data = agenda_attr_daily
)

summary(model_H2_0)

#模型 2：lag1 滞后效应
model_H2_1 <- lm(
  log_engagement ~ news_lag1 + attribute,
  data = agenda_attr_daily
)

summary(model_H2_1)

#按属性分别跑模型
# lag0（当天效应）模型
model_H2_lag0_by_attr <- agenda_attr_daily %>%
  group_by(attribute) %>%
  do(
    model = lm(
      log_engagement ~ news_count,
      data = .
    )
  )

# 查看模型列表
model_H2_lag0_by_attr

# Health
summary(model_H2_lag0_by_attr$model[[1]])

# Organizational Responsibility
summary(model_H2_lag0_by_attr$model[[2]])

# Structural
summary(model_H2_lag0_by_attr$model[[3]])

#lag1 模型
model_H2_by_attr <- agenda_attr_daily %>%
  group_by(attribute) %>%
  do(
    model = lm(log_engagement ~ news_lag1, data = .)
  )

model_H2_by_attr

summary(model_H2_by_attr$model[[1]])
summary(model_H2_by_attr$model[[2]])
summary(model_H2_by_attr$model[[3]])

#画图
library(dplyr)
library(tidyr)

plot_data <- agenda_attr_daily %>%
  select(attribute, log_engagement, news_count, news_lag1) %>%
  pivot_longer(
    cols = c(news_count, news_lag1),
    names_to = "lag_type",
    values_to = "news_value"
  ) %>%
  mutate(
    lag_type = recode(
      lag_type,
      news_count = "Lag 0 (Same Day)",
      news_lag1  = "Lag 1 (Next Day)"
    )
  )

#Health 图
library(ggplot2)

plot_data %>%
  filter(attribute == "Health") %>%
  ggplot(aes(x = news_value, y = log_engagement, color = lag_type)) +
  geom_point(alpha = 0.35) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    title = "Health Framing: Same-Day vs Next-Day Effects",
    x = "News Coverage (Count)",
    y = "Log Weibo Engagement",
    color = "Lag Type"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

#Organizational Responsibility 图
plot_data %>%
  filter(attribute == "Organizational Responsibility") %>%
  ggplot(aes(x = news_value, y = log_engagement, color = lag_type)) +
  geom_point(alpha = 0.35) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    title = "Organizational Responsibility Framing",
    x = "News Coverage (Count)",
    y = "Log Weibo Engagement",
    color = "Lag Type"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

#Structural 图
plot_data %>%
filter(attribute == "Structural") %>%
  ggplot(aes(x = news_value, y = log_engagement, color = lag_type)) +
  geom_point(alpha = 0.35) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    title = "Structural Framing Effects",
    x = "News Coverage (Count)",
    y = "Log Weibo Engagement",
    color = "Lag Type"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

#############################H3 检验###########################################
#构造 Python 需要的最小数据表
library(dplyr)

news_for_python <- news_raw %>%
  select(
    date = date_clean,
    Abstract
  ) %>%
  filter(!is.na(Abstract))

weibo_for_python <- weibo_attr %>%
  select(
    date,
    text_content
  ) %>%
  filter(!is.na(text_content))

write.csv(
  news_for_python,
  "C:/Users/97201/Desktop/6601 R code/news_raw.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  weibo_for_python,
  "C:/Users/97201/Desktop/6601 R code/weibo_raw.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

#用python跑情感分析，读入并合并
library(dplyr)

news_sent <- read.csv("C:/Users/97201/Desktop/6601 R code/news_daily_sentiment.csv")
weibo_sent <- read.csv("C:/Users/97201/Desktop/6601 R code/weibo_daily_sentiment.csv")

h3_data <- news_sent %>%
  inner_join(weibo_sent, by = "date") %>%
  arrange(date) %>%
  mutate(
    news_sent_lag1 = dplyr::lag(news_sentiment_mean, 1)
  )

#H3数据描述性统计
describe(
  h3_data[, c("news_sentiment_mean", "weibo_sentiment_mean")]
)

#Pearson相关分析
#当天情绪相关（Lag 0）
cor_test_lag0 <- cor.test(
  h3_data$news_sentiment_mean,
  h3_data$weibo_sentiment_mean,
  method = "pearson"
)

cor_test_lag0

#滞后一天的情绪相关（Lag 1）
cor_test_lag1 <- cor.test(
  h3_data$news_sent_lag1,
  h3_data$weibo_sentiment_mean,
  method = "pearson",
  use = "complete.obs"
)

cor_test_lag1


#H3 回归（lag0 & lag1）
# 同日（lag0）
model_h3_0 <- lm(
  weibo_sentiment_mean ~ news_sentiment_mean,
  data = h3_data
)
summary(model_h3_0)

# 滞后一天（lag1）
model_h3_1 <- lm(
  weibo_sentiment_mean ~ news_sent_lag1,
  data = h3_data
)
summary(model_h3_1)

#快速可视化
library(ggplot2)

ggplot(h3_data, aes(x = news_sentiment_mean, y = weibo_sentiment_mean)) +
  geom_point(alpha = 0.5) +
  geom_smooth(method = "lm") +
  labs(
    x = "News Sentiment (Mean)",
    y = "Weibo Sentiment (Mean)",
    title = "Affective Tone Alignment between News and Weibo (H3)"
  ) +
  theme_minimal()

library(broom)
library(dplyr)
library(ggplot2)

# 提取回归结果
h3_coef <- bind_rows(
  tidy(model_h3_0) %>% mutate(lag = "Lag 0"),
  tidy(model_h3_1) %>% mutate(lag = "Lag 1")
) %>%
  filter(term != "(Intercept)") %>%   # 只保留新闻情绪
  mutate(
    ci_low  = estimate - 1.96 * std.error,
    ci_high = estimate + 1.96 * std.error
  )

ggplot(h3_coef, aes(x = lag, y = estimate)) +
  geom_point(size = 3) +
  geom_errorbar(
    aes(ymin = ci_low, ymax = ci_high),
    width = 0.15,
    linewidth = 0.8
  ) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  labs(
    title = "Sentiment-Level Agenda-Setting Effects (H3)",
    x = NULL,
    y = "Regression Coefficient (β)"
  ) +
  theme_minimal(base_size = 13)

ggplot(h3_coef, aes(y = lag, x = estimate)) +
  geom_point(size = 3) +
  geom_errorbarh(
    aes(xmin = ci_low, xmax = ci_high),
    height = 0.15,
    linewidth = 0.8
  ) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  labs(
    title = "Sentiment-Level Agenda-Setting Effects (H3)",
    y = NULL,
    x = "Regression Coefficient (β)"
  ) +
  theme_minimal(base_size = 13)


###########################H4 检验##########################################
#python进行情感维度分析
# 如果没装过
# install.packages(c("tidyverse", "lubridate", "broom"))
library(tidyverse)
library(lubridate)
library(broom)

#读取DLUT 情绪数据（新闻 & 微博）
news_emotion <- read_csv(
"C:/Users/97201/Desktop/6601 R code/news_daily_dlut_emotion.csv"
)

weibo_emotion <- read_csv(
  "C:/Users/97201/Desktop/6601 R code/weibo_daily_emotion_dlutt.csv"
)

news_emotion$date <- as.Date(news_emotion$date)
weibo_emotion$date <- as.Date(weibo_emotion$date)

#合并数据
emotion_daily <- full_join(
  news_emotion,
  weibo_emotion,
  by = "date",
  suffix = c("_news", "_weibo")
) %>%
  arrange(date)

glimpse(emotion_daily)

#构造 lag 变量（lag1，和 H3 保持一致）
emotion_daily <- emotion_daily %>%
  mutate(
    joy_news_lag1 = lag(joy_news, 1),
    good_news_lag1 = lag(good_news, 1),
    anger_news_lag1 = lag(anger_news, 1),
    sadness_news_lag1 = lag(sadness_news, 1),
    fear_news_lag1 = lag(fear_news, 1),
    disgust_news_lag1 = lag(disgust_news, 1),
    surprise_news_lag1 = lag(surprise_news, 1)
  )

#描述性统计
describe(emotion_daily)

#Pearson相关性分析
emotions <- c("joy", "good", "sadness", "fear", "disgust", "surprise")

#lag 0
cor_lag0 <- map_df(
  emotions,
  function(e) {
    test <- cor.test(
      emotion_daily[[paste0(e, "_news")]],
      emotion_daily[[paste0(e, "_weibo")]],
      use = "complete.obs"
    )
    tibble(
      emotion = e,
      correlation = test$estimate,
      p_value = test$p.value
    )
  }
)

cor_lag0

#lag 1
cor_lag1 <- map_df(
  emotions,
  function(e) {
    test <- cor.test(
      emotion_daily[[paste0(e, "_news_lag1")]],
      emotion_daily[[paste0(e, "_weibo")]],
      use = "complete.obs"
    )
    tibble(
      emotion = e,
      correlation = test$estimate,
      p_value = test$p.value
    )
  }
)

cor_lag1

#合并表格
cor_all <- cor_lag0 %>%
  mutate(lag = "lag0") %>%
  bind_rows(
    cor_lag1 %>% mutate(lag = "lag1")
  ) %>%
  arrange(emotion, lag)

cor_all

#回归模型
#GOOD（lag0）
model_h4_good_0 <- lm(
  good_weibo ~ good_news,
  data = emotion_daily
)

summary(model_h4_good_0)

#GOOD（lag1)
model_h4_good_1 <- lm(
  good_weibo ~ good_news_lag1,
  data = emotion_daily
)

summary(model_h4_good_1)

#DISGUST（lag0）
model_h4_disgust_0 <- lm(
  disgust_weibo ~ disgust_news,
  data = emotion_daily
)

summary(model_h4_disgust_0)

#DISGUST（lag1）
model_h4_disgust_1 <- lm(
  disgust_weibo ~ disgust_news_lag1,
  data = emotion_daily
)

summary(model_h4_disgust_1)

#SADNESS（只 lag1）
model_h4_sadness_1 <- lm(
  sadness_weibo ~ sadness_news_lag1,
  data = emotion_daily
)

summary(model_h4_sadness_1)

#第一步：整理成长格式数据
library(tidyverse)

# 只保留 H4 显著的 3 个情绪
emotion_long <- emotion_daily %>%
  select(
    date,
    
    # good
    good_news, good_news_lag1, good_weibo,
    
    # disgust
    disgust_news, disgust_news_lag1, disgust_weibo,
    
    # sadness（只有 lag1）
    sadness_news_lag1, sadness_weibo
  ) %>%
  
  pivot_longer(
    cols = -c(date, good_weibo, disgust_weibo, sadness_weibo),
    names_to = "news_var",
    values_to = "news_value"
  ) %>%
  
  mutate(
    emotion = case_when(
      str_detect(news_var, "good") ~ "Good",
      str_detect(news_var, "disgust") ~ "Disgust",
      str_detect(news_var, "sadness") ~ "Sadness"
    ),
    lag = case_when(
      str_detect(news_var, "lag1") ~ "Lag 1 (Next day)",
      TRUE ~ "Lag 0 (Same day)"
    ),
    weibo_value = case_when(
      emotion == "Good" ~ good_weibo,
      emotion == "Disgust" ~ disgust_weibo,
      emotion == "Sadness" ~ sadness_weibo
    )
  ) %>%
  
  # sadness 只保留 lag1
  filter(!(emotion == "Sadness" & lag == "Lag 0 (Same day)"))

#画H4回归可视化图
library(ggplot2)

ggplot(
  emotion_long,
  aes(x = news_value, y = weibo_value, color = lag)
) +
  geom_point(alpha = 0.5, size = 2) +
  
  geom_smooth(
    method = "lm",
    se = TRUE,
    linewidth = 1
  ) +
  
  facet_wrap(~ emotion, scales = "free") +
  
  scale_color_manual(
    values = c(
      "Lag 0 (Same day)" = "#E69F00",
      "Lag 1 (Next day)" = "#56B4E9"
    )
  ) +
  
  labs(
    title = "Lagged Effects of News Emotional Attributes on Social Media Emotions",
    x = "Emotional Intensity in News Coverage",
    y = "Emotional Intensity in Weibo Discussions",
    color = "Lag Type"
  ) +
  
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold", hjust = 0.5)
  )

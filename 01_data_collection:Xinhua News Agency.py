import requests
from lxml import etree
from bs4 import BeautifulSoup
import pandas as pd
import time
import os

# 全局变量用于存储所有数据
all_data = []


def first():
    global all_data

    for page in range(10, 12): # 自行修改页数爬取
        print(f'\n---------------------正在下载: 第{page}页数据------------------------\n')

        # 每页之间延时1秒
        if page > 1:
            time.sleep(1)

        headers = {
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'zh-CN,zh;q=0.9',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Pragma': 'no-cache',
            'Referer': 'https://so.news.cn/',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
            'sec-ch-ua': '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"Windows"',
            'Cookie': 'wdcid=5ea516078d46eb45; xinhuatoken=news; wdlast=1766218831',
        }
        params = {
            'lang': 'cn',
            'curPage': '{}'.format(page),
            'searchFields': '0',
            'sortField': '0',
            'keyword': '职业健康',
        }
        response = requests.get('https://so.news.cn/getNews', params=params, headers=headers).json()

        results = response['content']['results']

        page_data = []  # 存储当前页的数据

        for info in results:
            # 标题
            title = info['title']
            print(f"标题: {title}")
            # 时间
            pubtime = info['pubtime']
            print(f"时间: {pubtime}")
            # 链接
            url = info['url']
            print(f"链接: {url}")


            # 获取详情页数据
            ly, content = second(title, pubtime, url, headers)

            # 存储数据
            data_item = {
                '标题': title,
                '时间': pubtime,
                '链接': url,
                '来源': ly,
                '正文内容': content
            }
            page_data.append(data_item)

        # 将当前页数据添加到总数据中
        all_data.extend(page_data)

        # 每保存一页数据到Excel
        save_to_excel(page)


def second(title, pubtime, url, headers):
    # 1. 补齐域名
    if url.startswith('http'):
        full_url = url
    else:
        # 去掉可能存在的 "null" 前缀，再拼域名
        full_url = 'https://www.news.cn/' + url.replace('null/', '', 1).lstrip('/')

    try:
        response = requests.get(full_url, headers=headers, timeout=10).content.decode()
    except Exception as e:
        print(f'详情页下载失败: {full_url}  错误: {e}')
        return '', ''      # 返回空字符串，让主流程继续

    A = etree.HTML(response)
    soup = BeautifulSoup(response, "html.parser")

    # 来源class="main clearfix"
    ly = A.xpath('//div[@class="source"]/text()')
    ly_text = ly[0].strip() if ly else ""
    print(f"来源: {ly_text}")

    # 正文内容
    content = ""
    newstxt_div = soup.find("div", class_="main clearfix")
    if newstxt_div:
        content = newstxt_div.get_text(strip=True)
        print(f"正文内容长度: {len(content)}字符")
    else:
        print("未找到正文内容")

    return ly_text, content


def save_to_excel(page_num):
    """保存数据到Excel"""
    global all_data

    if not all_data:
        print("没有数据可保存")
        return

    # 创建DataFrame
    df = pd.DataFrame(all_data)

    # 保存到Excel文件
    filename = "news_data.xlsx"

    # 如果是第一页，直接保存；如果不是第一页，需要追加或覆盖
    if page_num == 1:
        # 第一页，直接创建新文件
        df.to_excel(filename, index=False, engine='openpyxl')
        print(f"第{page_num}页数据保存成功到 {filename}")

        # 打印每个标题保存成功
        for idx, row in df.iterrows():
            print(f"标题保存成功: {row['标题'][:50]}...")  # 只显示前50个字符避免过长
    else:
        try:
            # 检查文件是否存在
            if os.path.exists(filename):
                # 读取现有数据
                existing_df = pd.read_excel(filename, engine='openpyxl')
                # 合并数据
                combined_df = pd.concat([existing_df, df], ignore_index=True)
                # 去重（基于标题）
                combined_df = combined_df.drop_duplicates(subset=['标题'], keep='first')
                # 保存
                combined_df.to_excel(filename, index=False, engine='openpyxl')
            else:
                # 如果文件不存在，直接保存
                df.to_excel(filename, index=False, engine='openpyxl')

            print(f"第{page_num}页数据保存成功到 {filename}")

            # 打印当前页的每个标题保存成功
            current_page_data = all_data[-len(df):]  # 获取当前页的数据
            for item in current_page_data:
                print(f"标题保存成功: {item['标题'][:50]}...")

        except Exception as e:
            print(f"保存Excel时出错: {e}")


if __name__ == '__main__':
    first()

    # 最终保存确认
    if all_data:
        print(f"数据采集完成，共采集 {len(all_data)} 条数据")
        print(f"数据已保存到 news_data.xlsx")
    else:
        print("没有采集到任何数据")
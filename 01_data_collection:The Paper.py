import time

import requests
import json
from lxml import etree
import csv
headers = {
    "accept": "application/json",
    "accept-language": "zh-CN,zh;q=0.9",
    "client-type": "1",
    "content-type": "application/json",
    "origin": "https://www.thepaper.cn",
    "priority": "u=1, i",
    "referer": "https://www.thepaper.cn/",
    "sec-ch-ua": "\"Google Chrome\";v=\"143\", \"Chromium\";v=\"143\", \"Not A(Brand\";v=\"24\"",
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "\"Windows\"",
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-site",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"
}
cookies = {
    "Hm_lvt_94a1e06bbce219d29285cee2e37d1d26": "1768792194",
    "HMACCOUNT": "A8A23C497F36593C",
    "ariaDefaultTheme": "undefined",
    "Hm_lpvt_94a1e06bbce219d29285cee2e37d1d26": "1768792199",
    "tfstk": "gOpZEhGjJAHaTmuk43XqL8UG3mWOLtuWnK_fmnxcfNbgCRaDT3LM1ZGOh-5c8ECfSNiO3sYDSid15GiVmOpB1-_sWt-DPtuSPYMWXhCAn4gSK_g7qTj8n-4fiy2hhir_n9K9XhBYvgvy-qtt3egc4GXDo9fh2g6cj1bmYWjR-Rj0Ii4nYiQhnRXcsJxh0G40i5YDxDSA-ZXcsEXnYiQhotXmw0YDWJ7FsD3hNSmnze1NrhbUUHpFjf_SeNy0opjwYa-MM-2DLG5wLGFPxG56i3CJCnk4pOtyt9j2H0VVu_RDC9vi-YfdipYhxFibMMR2mLBO1oevzO8VZdfUm8xO3NBFxLmbww9F5EvNt0wPG9v5ZOAI9V1fQg8DBFr4nUxBVdCp34zhkCsRKiJxqS7VigWbkMf7iKdaoS5GvM7SYDP5yLs_YPtMSSFATXIFP0n8MSCMWM7SYGNYM6qdYaiN2"
}


def detail():
    cd = csv.reader(open('原始数据.csv', 'r', encoding='utf-8-sig'))
    for i in cd:
        url = i[-1]
        print(url)
        time.sleep(1)
        response = requests.get(url, headers=headers)
        html = etree.HTML(response.text)
        text = ''.join(html.xpath('//div[@class="cententWrap__UojXm"]//p//text()')).replace('\n', '')
        info = ''.join(html.xpath('//div[@class="left__IlIiv"]//div[@class="ant-space ant-space-horizontal ant-space-align-center"]/div[@class="ant-space-item"]/span/text()'))
        content = ''.join(html.xpath('//meta[@property="og:description"]/@content'))
        with open('新闻数据.csv', 'a+', encoding='utf-8-sig', newline='') as fi:
            fi = csv.writer(fi)
            fi.writerow(
                i + [text, info, content]
            )


def qc():
    a = {}
    cd = csv.reader(open('原始数据.csv', 'r', encoding='utf-8-sig'))
    for i in cd:
        a.update({i[-1]: i})
    for i in a.items():
        with open('数据.csv', 'a+', encoding='utf-8-sig', newline='') as fi:
            fi = csv.writer(fi)
            fi.writerow(
                i[1]
            )

def start():
    keys = [
        '加班',
        '996',
        '劳动法',
        '加班费',
        '工作压力',
        '职场焦虑',
        '职场压力',
        '工作焦虑',
        '工作倦怠',
        '工作过劳',
        '工作疲惫',
        '职业倦怠',
        '工作躺平',
        '企业责任',
        '员工关怀',
        '职业健康','职场内卷',
        '职场竞争',
        '职场PUA',
        '职场霸凌',
        '职场心理质询',
        '职场心里健康',
        '职场关怀'
        ]
    for key_ in keys:
        for page_num in range(1, 101):
            time.sleep(3)
            print(page_num, key_)
            code = False
            url = "https://api.thepaper.cn/search/web/news"
            data = {
                "word": key_,
                "orderType": 1,
                "pageNum": page_num,
                "pageSize": 10,
                "searchType": 1
            }
            response = requests.post(url, headers=headers, cookies=cookies, json=data).json()
            trs = response['data']['list']
            if trs == []:
                break
            else:
                for tr in trs:
                    contId = tr['contId']
                    name = tr['name']
                    pubTime = tr['pubTime']
                    if '2025-11' in str(pubTime):
                        code = True
                        break
                    else:
                        if '2025-12' in str(pubTime):
                            html = etree.HTML(str(tr.get('summary')))
                            text = ''.join(html.xpath('//text()')).replace('\n', '')
                            nodeInfo = tr['nodeInfo']['name']
                            link = f'https://www.thepaper.cn/newsDetail_forward_{contId}'
                            print(link)
                            with open('原始数据.csv', 'a+', encoding='utf-8-sig', newline='') as fi:
                                fi = csv.writer(fi)
                                fi.writerow(
                                    [key_, contId, name, pubTime, text, nodeInfo, link]
                                )
                if code:
                    break


detail()
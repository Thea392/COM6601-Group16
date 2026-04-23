import pandas as pd

def delete_rows_with_keywords_in_text_content(file_path, keywords, output_path=None, sheet_name=None):
    """
    删除Excel中Text Content列包含指定关键词组合的行
    
    参数:
    file_path: Excel文件路径
    keywords: 包含两个关键词的列表，如['关键词1', '关键词2']
    output_path: 输出文件路径，如果不指定则在原文件名后加'_filtered'
    sheet_name: 工作表名称，如果不指定则读取第一个工作表
    """
    
    # 读取Excel文件
    try:
        if sheet_name:
            df = pd.read_excel(file_path, sheet_name=sheet_name)
        else:
            df = pd.read_excel(file_path)
    except Exception as e:
        print(f"读取Excel文件失败: {e}")
        return
    
    print(f"原始数据行数: {len(df)}")
    
    # 检查是否存在Text Content列
    if 'Text Content' not in df.columns:
        print("错误：Excel文件中找不到'Text Content'列")
        print("可用的列名：", df.columns.tolist())
        return
    
    # 在Text Content列中搜索关键词
    def contains_all_keywords(text_content):
        if pd.isna(text_content):  # 处理空值
            return False
        text = str(text_content)
        # 检查是否同时包含所有关键词
        return all(keyword in text for keyword in keywords)
    
    # 标记需要删除的行（Text Content列同时包含所有关键词的行）
    rows_to_delete = df['Text Content'].apply(contains_all_keywords)
    
    # 删除这些行
    df_filtered = df[~rows_to_delete]
    
    print(f"删除后数据行数: {len(df_filtered)}")
    print(f"删除了 {sum(rows_to_delete)} 行")
    
    # 确定输出文件路径
    if not output_path:
        import os
        base_name = os.path.splitext(file_path)[0]
        output_path = f"{base_name}_filtered.xlsx"
    
    # 保存结果
    try:
        df_filtered.to_excel(output_path, index=False)
        print(f"处理完成，结果已保存到: {output_path}")
        return output_path
    except Exception as e:
        print(f"保存文件失败: {e}")
        return None

def main():
    # 使用示例
    file_path = r"D:\6601\【第三版】微博爬虫\微博搜索结果3月-4月 - 清洗后\3月\微博搜索结果_整合_20250331_20260101.xlsx"  # 替换为你的Excel文件路径
    keywords = ["[加班吧]", "[小繁花]"]  # 替换为你要搜索的两个关键词
    
    # 执行删除操作
    output_file = delete_rows_with_keywords_in_text_content(
        file_path=file_path,
        keywords=keywords,
        sheet_name=None  # 如果需要指定工作表，请修改这里
    )
    
    if output_file:
        print(f"成功处理文件，输出文件: {output_file}")

if __name__ == "__main__":
    main()
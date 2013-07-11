# -*- coding: utf-8; tab-width: 4 -*-
# Author: Yasutaka SHINDOH

############################################################
## description

## 本パッケージを用いることで、
## 人手で左右の文脈IDおよびコストを付与することなく、
## UniDicのユーザー辞書バイナリを以下の手順で生成できる。

## (1) UniDicの辞書およびCRF学習モデルのアーカイブ・ファイルを取得する。
## (2) アーカイブ・ファイルを本Makefileと同じディレクトリに置く。
## (3) 辞書内の*.csvファイルを参考にuser.csvファイルを編集する。
## (4) Makefileのあるディレクトリでコマンド「make」を実行する。

## * UniDicの辞書およびCRF学習モデルのアーカイブ・ファイルは
##   http://sourceforge.jp/projects/unidic/ から取得できる。

## * Ruby 1.8が必要。

############################################################
## variables

UNIDIC_DICTIONARY_ARCHIVE	:= $(wildcard unidic-mecab-*_src.*)
UNIDIC_MODEL_ARCHIVE		:= $(wildcard unidic-mecab-*_model.*)

USER_DICTIONARY_CSV			:= user.csv
ADDITIONAL_DICTIONARY_CSV	:= addition.csv
USER_DICTIONARY_DIC			:= $(patsubst %.csv,%.dic,$(USER_DICTIONARY_CSV))

WORK_DIRECTORY				:= work
UNIDIC_DICTIONARY_DIRECTORY	:= $(WORK_DIRECTORY)/dictionary
UNIDIC_MODEL_DIRECTORY		:= $(WORK_DIRECTORY)/crf_model

CHECK_SENTENCE				:= ネットでdisられるアーティスト。


############################################################
## targets

all: $(USER_DICTIONARY_DIC) $(ADDITIONAL_DICTIONARY_CSV)

$(UNIDIC_DICTIONARY_DIRECTORY): $(UNIDIC_DICTIONARY_ARCHIVE)
	# create: $(@F)
	@mkdir -p $@
	unzip -d $@ $< || : 'ignore errors!'
	for f in `find $@ -name '*.def' -print` ; do \
		mv $$f $$f.orig ; \
		env LC_ALL=C tr -d '\r' < $$f.orig > $$f ; \
	done
	for f in `find $@ -name '*.csv' -print` ; do \
		mv $$f $$f.orig ; \
		env LC_ALL=C tr -d '\r' < $$f.orig > $$f ; \
	done
	cd `find $@ -name 'dicrc' | env LC_ALL=C sed -r 's|[^/]*$$||'` \
	&& $(shell mecab-config --libexecdir)/mecab-dict-index -t 'UTF-8' -f 'UTF-8'

$(UNIDIC_MODEL_DIRECTORY): $(UNIDIC_MODEL_ARCHIVE)
	# create: $(@F)
	@mkdir -p $@
	unzip -d $@ $< || : 'ignore errors!'
	for f in `find $@ -type f -name '*model*' -print` ; do \
		mv $$f $$f.orig ; \
		env LC_ALL=C tr -d '\r' < $$f.orig > $$f ; \
	done

$(ADDITIONAL_DICTIONARY_CSV): $(UNIDIC_DICTIONARY_DIRECTORY)
	# create: $(@F)
	@mkdir -p $(@D)
	cat `find $^ -name '*.csv' -print | env LC_ALL=C grep -Ev '\.orig$$'` \
	| ruby -Ku -ne 'print $$_ if $$_ =~ /\A[Ａ-Ｚａ-ｚ０-９]+[ぁ-ん]*,/' \
	| ruby -Ku -r jcode -ne 'print $$_.sub($$&, $$&.tr("Ａ-Ｚａ-ｚ０-９", "A-Za-z0-9")) if $$_ =~ /\A[^,]+,/' \
	| env LC_ALL=C sed -r 's|^([^,]+),[0-9]+,[0-9]+,[0-9]+,|\1,,,,|' > $@

$(USER_DICTIONARY_DIC): $(USER_DICTIONARY_CSV) $(ADDITIONAL_DICTIONARY_CSV) $(UNIDIC_DICTIONARY_DIRECTORY) $(UNIDIC_MODEL_DIRECTORY)
	# create: $(@F)
	@mkdir -p $(@D)
	$(shell mecab-config --libexecdir)/mecab-dict-index \
	-t 'UTF-8' -f 'UTF-8' \
	-m `find $(UNIDIC_MODEL_DIRECTORY) -type f -name '*model*' | env LC_ALL=C grep -Ev '\.orig$$'` \
	-d `find $(UNIDIC_DICTIONARY_DIRECTORY) -name 'dicrc' | env LC_ALL=C sed -r 's|/[^/]*$$||'` \
	-u $@ $(USER_DICTIONARY_CSV) $(ADDITIONAL_DICTIONARY_CSV)

check: $(USER_DICTIONARY_DIC) $(UNIDIC_DICTIONARY_DIRECTORY)
	# check
	echo "$(CHECK_SENTENCE)" \
	| mecab -u $(USER_DICTIONARY_DIC) -d `find $(UNIDIC_DICTIONARY_DIRECTORY) -name 'dicrc' | env LC_ALL=C sed -r 's|[^/]*$$||'`

clean:
	# clean
	rm -rf $(UNIDIC_DICTIONARY_DIRECTORY) $(UNIDIC_MODEL_DIRECTORY)
	rm -f $(ADDITIONAL_DICTIONARY_CSV) $(USER_DICTIONARY_DIC)
	find . -name '*~' -print0 | xargs -0 rm -f
	for d in $(sort $(dir $(UNIDIC_DICTIONARY_DIRECTORY) $(UNIDIC_MODEL_DIRECTORY) $(ADDITIONAL_DICTIONARY_CSV) $(USER_DICTIONARY_DIC))) ; do \
		if [ -d $$d ] ; then rmdir -p $$d 2>/dev/null || : 'ignore errors' ; fi \
	done

.PHONY: all check clean

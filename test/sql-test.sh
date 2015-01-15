#!/usr/bin/env bash
set -e -u -o pipefail

passcount=0
failcount=0

psql="psql -U postgres -d testdb"
$psql -f $(dirname $0)/../lib.sql

function tf() {
    # tf (test a function)
    # Usage: tf function_name argument expected-output
    result=$($psql -c "COPY (SELECT $1($2)) TO STDOUT;")
    if [[ "$result" == "$3" ]]; then
        echo -e "✔ $2 ⇒ '$result' "
        passcount=$((passcount+1))
    else
        echo -e "✘ $2 ⇒ '$result' "
        echo "  ⤷ expected: '$3'"
        failcount=$((failcount+1))
    fi
}

echo -e "testing clean_int:"
tf clean_int "'123'"            "123"
tf clean_int "'foobar'"         "\\N"
tf clean_int "'2147483647'"     "2147483647"  # largest possible int
tf clean_int "'-2147483648'"    "-2147483648"  # smallest possible int
tf clean_int "'9999999999'"     "\\N"  # out of range, returns null
tf clean_int "'123.456'"        "123"  # round down
tf clean_int "'456.789'"        "457"  # round up

echo -e "testing z:"
tf z "1000000000" "\\N"
tf z "500000000" "0"
tf z "1000" "19"

echo -e "testing zres:"
tf zres "0" "156543.033928041"
tf zres "19" "0.29858214173897"

echo -e "testing linelabel:"
tf linelabel "14, 'Foobar', ST_GeomFromText('POINT(0 0)',900913)" "t"
tf linelabel "14, 'Foobar', ST_GeomFromText('LINESTRING(0 0, 0 300)',900913)" "f"
tf linelabel "15, 'Foobar', ST_GeomFromText('LINESTRING(0 0, 0 300)',900913)" "t"

echo -e "testing labelgrid:"
tf labelgrid "ST_GeomFromText('POINT(100 -100)',900913), 64, 9.5546285343" \
    "POINT(305.7481130976 -305.7481130976)"

echo -e "testing topoint:"
tf topoint "ST_GeomFromText('POINT(0 0)',900913)" \
    "010100002031BF0D0000000000000000000000000000000000"
tf topoint "ST_GeomFromText('POLYGON EMPTY',900913)" "\\N"
tf topoint "ST_GeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))',900913)" \
    "010100002031BF0D0000000000000014400000000000001440"
tf topoint "ST_GeomFromText('POLYGON((0 0, 10 0, 0 10, 10 10, 0 0))',900913)" \
    "010100002031BF0D0000000000000014400000000000000440"

echo -e "testing merc_buffer:"
tf merc_buffer "ST_GeomFromText('LINESTRING(0 0, 1000 1000)', 900913), 500" \
    "010300002031BF0D000100000023000000731062A792338440C6F74EAC36269540F2466314B8918640A2CC5B71F01E96404072FF2944458940C4187552C2D79640E8DF7782A3338C406503AB10924997400400000000408F406C1A6700007097401010C43E2E2691406403AB1092499740E44600EB5D9D9240C2187552C2D796408A5CCEF523F793409FCC5B71F01E9640C6F74EAC36269540C6F74EAC362695409FCC5B71F01E96408A5CCEF523F79340C2187552C2D79640E44600EB5D9D92406403AB10924997401010C43E2E2691406C1A6700007097400400000000408F406503AB1092499740E8DF7782A3338C40C4187552C2D796404072FF2944458940A2CC5B71F01E9640F2466314B8918640C6F74EAC36269540731062A7923384401ADF3BB1DA1876401ADF3BB1DA1876C01E7239D78F5C714084326FC5C1FB79C005370258EFEA67400D63D44909DF7CC0C80041ECE3625840930DAC4248A67EC05BA45CD7774855BDB2699C0100407FC0F20041ECE36258C0910DAC4248A67EC018370258EFEA67C00963D44909DF7CC0257239D78F5C71C080326FC5C1FB79C01ADF3BB1DA1876C01ADF3BB1DA1876C07A326FC5C1FB79C02C7239D78F5C71C00763D44909DF7CC01F370258EFEA67C08F0DAC4248A67EC0100141ECE36258C0B2699C0100407FC0C4DFA62A88C761BD930DAC4248A67EC0AB0041ECE36258400E63D44909DF7CC0FE360258EFEA674089326FC5C1FB79C0177239D78F5C71401ADF3BB1DA1876C01ADF3BB1DA187640731062A792338440C6F74EAC36269540"
tf merc_buffer "ST_GeomFromText('POINT(0 8500000)', 900913), 500" \
    "010300002031BF0D000100000021000000AD8BBCE2E6AD8F4000000000643660414156388912128F40D7B458474B366041512E128792448D40B64DE6813336604169B1881123578A40F70785991D3660419C936B0E9166864052C6BB650A366041634D02BE9E998140DDB973A3FA356041AAC124D90C3F7840B7E3B5EDEE356041D1DD284BA7B868401FDBB5B7E7356041CCF7D8EFB7CF7C3D0E756448E535604160DD284BA7B868C01FDBB5B7E735604174C124D90C3F78C0B7E3B5EDEE3560414C4D02BE9E9981C0DDB973A3FA35604188936B0E916686C052C6BB650A36604159B1881123578AC0F70785991D366041462E128792448DC0B64DE681333660413B56388912128FC0D7B458474B366041AD8BBCE2E6AD8FC000000000643660414656388912128FC0294BA7B87C3660415C2E128792448DC04AB2197E943660417AB1881123578AC009F87A66AA366041B1936B0E916686C0AE39449ABD3660417B4D02BE9E9981C023468C5CCD366041DBC124D90C3F78C0491C4A12D93660412ADE284BA7B868C0E1244A48E0366041064475E09DA890BDF28A9BB7E236604124DD284BA7B86840E1244A48E036604161C124D90C3F7840491C4A12D9366041444D02BE9E99814023468C5CCD36604184936B0E91668640AE39449ABD36604159B1881123578A4009F87A66AA366041472E128792448D404AB2197E943660413C56388912128F40294BA7B87C366041AD8BBCE2E6AD8F400000000064366041"

echo -e "testing merc_length:"
tf merc_length "ST_GeomFromText('LINESTRING(0 0, 10000 0)', 900913)" \
    "10000"
tf merc_length "ST_GeomFromText('LINESTRING(0 8500000, 10000 8500000)', 900913)" \
    "4932.24215371697"

# summary:
echo -e "$passcount tests passed | $failcount tests failed"

exit $failcount
